
#### Plot stacked chart of intervals {{{
###
###

# Local override of str_squish to preserve &nbsp;
local_str_squish <- function(string) {
  stringi::stri_trim_both(stringr::str_replace_all(string, '[[\\s]-[\u00A0]]+', " "))
}

orig.str_split <- stringr::str_split
local_str_split <- function (string, pattern, n = Inf, simplify = FALSE) {
  if( pattern == "[[:space:]]+" ) {
    pattern <- "[[:space:]-[\u00A0]]+"
  }
  orig.str_split(string, pattern, n, simplify)
}

categorize_intervals <- function(interval_length, breakpoints) {
  label_incomplete <- as.character(
    glue("No results within {max(breakpoints)} months")
  )
  labels <- c(paste0(breakpoints, " months"),
              label_incomplete)

  #print(labels)
  # Create bins for cut() function including an Inf for the upper bound of the last interval
  bins <- c(-Inf, as.numeric(months(breakpoints) + days(1)), Inf)

  # Vectorized interval categorization using if_else and cut
  result <- if_else(
    is.na(interval_length),
    label_incomplete,
    cut(interval_length, bins, labels = labels, right = FALSE)
  ) |> as.factor()

  return(result)
}


process.single.agg.window.amend.agg.interval.groups <-
    function(agg.window.single,
             with_facet = "common.funding" ) {
  # Define breakpoints in months
  breakpoints <- 12*sequence(3)
  # ( 12*sequence(5) == c(12, 24, 36, 48, 60) ) |> all()

  agg.window.single$agg.interval.groups <-
    agg.window.single$hlact.studies |>
  mutate( agg.interval =
            interval(common.primary_completion_date_imputed, common.results_received_date),
       ) |>
  mutate( agg.results_reported_within =
            categorize_intervals(agg.interval, breakpoints)
       ) |>
  group_by(across(c(
                    (if(!is.null(with_facet))  with_facet ),
                    "agg.results_reported_within"))) |>
  summarize( agg.results_reported_within.count = n() ) |>
  mutate( agg.results_reported_within.pct =
           proportions(agg.results_reported_within.count) )

  return(agg.window.single)
}

process.all.agg.window.amend.agg.interval.groups <-
  function(agg.windows, with_facet = NULL ) {
  for(w_name in names(agg.windows)) {
    agg.windows[[w_name]] <- agg.windows[[w_name]] |>
      process.single.agg.window.amend.agg.interval.groups(
        with_facet = with_facet
      )
  }
  agg.windows[[1]]$agg.interval.groups |> names()

  return(agg.windows)
}

# plot.windows.stacked.chart(agg.windows)
plot.windows.stacked.chart <-
    function(agg.windows,
             with_names = FALSE,
             with_facet = "common.funding",
             window.time.label.oneline = FALSE,
             ggsave.opts = list(width = 12,
                             height = 8),
             fig.cb = NULL
     ) {

  window_names <- names(agg.windows)
  is_yearly_obs36 <- str_starts(window_names[1], "yearly_obs36")

  faceted_by.label <- with_facet
  if( is.null(with_facet) ) {
    faceted_by.label <- 'overall'
  }
  faceted_by.label <- gsub("^common\\.", "", faceted_by.label)

  agg.windows <- agg.windows |>
    process.all.agg.window.amend.agg.interval.groups(with_facet = with_facet)

  #agg.windows |>
  #  map( ~ .x$agg.interval.groups |> print() )

  n.groups <- agg.windows |>
    map( ~ .x$agg.interval.groups |> nrow() ) |>
    as.integer() |> max() + 1

  windows.result_reported_within <-
    agg.windows |>
    imap( ~ .x$agg.interval.groups |>
        mutate(start  = .x$window$date$start,
               stop   = .x$window$date$stop,
               cutoff = .x$window$date$cutoff,
               window_name = .y,)) |>
    list_rbind()

  fig.result_reported_within.stacked_area <- {
    # Cleaner than `assignInNamespace`
    local_mocked_bindings(str_squish = local_str_squish, .package = 'stringr')
    local_mocked_bindings(str_split = local_str_split, .package = 'stringr')
    df <-
      windows.result_reported_within |>
        mutate(
               n          = agg.results_reported_within.count,
               time       = cutoff,
               pct        = agg.results_reported_within.pct,
               grp        = forcats::fct_rev(agg.results_reported_within),
        )
    if(!is.null(with_facet)) {
      df <- df |>
        mutate(
               facet = !!rlang::sym(with_facet)
        )
    }

    #print(df)
    color.text.primary <- 'black'
    color.text.secondary <- '#8a8a8a'
    (span.style.primary <-
      ( if( is.null(with_facet) ) { glue('color:{color.text.primary}; font-size:16pt') }
        else { glue('color:{color.text.primary}; font-size:12pt') } ) )
    ( span.style.secondary <-
      ( if( is.null(with_facet) ) { glue('color: {color.text.secondary}; font-size:12pt') }
        else { glue('color: {color.text.secondary}') } ) )
    if( window.time.label.oneline ) {
      window.year.glue_format <- "<span style='{span.style.secondary}'>{year(start)}–{year(stop)}<br>Cutoff {year(cutoff)}</span>"
    } else {
      window.year.glue_format <-
        if(is_yearly_obs36) "<span style='{span.style.secondary}; text-align:left'>{year(start)}–<br>{year(stop)}</span>"
        else "<span style='{span.style.secondary}'>{year(start)}–<br>{year(stop)}<br>Cutoff {year(cutoff)}</span>"
    }
    if( with_names ) {
      name.glue_format <- "<span style='{span.style.primary}'><b>{
            str_replace_all(window_name, ' ', '\u00A0') |>
            str_wrap(20) |>
              str_replace_all('\n', '<br>')
          }</b></span><br>"
    } else {
      name.glue_format <- ""
    }

    count.label.glue_format <- "<span style='{span.style.secondary}'>(N = {scales::comma(n)})</span>"

    time.label.glue_format <- paste(name.glue_format,
                                    window.year.glue_format,
                                    count.label.glue_format,
                                    sep = '<br>')
    if(is_yearly_obs36) {
      count.label.glue_format <- "<span style='color: {color.text.secondary}; font-size:6pt'>(N = {scales::comma(n)})</span>"
      time.label.glue_format <- paste(window.year.glue_format,
                                      count.label.glue_format,
                                      sep = '<br>')
    }

    # Create time labels with facet-specific N values
    time.label.df <- df |>
      group_by(across(c(
                "time",
                "window_name",
                "start", "stop", "cutoff",
                (if(!is.null(with_facet)) "facet" )))) |>
      summarize(
        n = sum(agg.results_reported_within.count),
        .groups = "drop"
      ) |>
      mutate(
        full.label = glue(time.label.glue_format),
        x.label = glue(paste(name.glue_format,
                             window.year.glue_format,
                             sep = '<br>'))
      )
    #print(time.label.df |> pull(full.label))

    fig <- ggplot(df,
           aes(x = time, y = pct, fill = grp) ) +
           # allow drawing outside plot area
           coord_cartesian(clip = "off")

    if(!is.null(with_facet)) {
      fig <- fig + facet_wrap(~ facet, strip.position = "bottom")
    }

    fig <- fig +
      geom_bar(stat = "identity") +
      geom_text(aes(label = ifelse(pct > 0.01, sprintf("%1.0f%%", 100*pct), '')),
                position = position_stack(vjust = 0.5),
                size = 6, family='mono', fontface = 'bold',
                color = "black" # "#fdfdfd" "black"
                ) +
      ggtext::geom_richtext(
        data = time.label.df,
        aes(x = time, y = -0.05, label = full.label),
        stat = "identity",
        position = "identity",
        inherit.aes = FALSE,
        hjust = 0.5,
        vjust = 0.85,
        size = 3.5,
        lineheight = 0.5,
        fill = NA,
        label.color = NA
      ) +
      scale_x_discrete(labels = time.label.df |> pull(x.label) )  +
      scale_y_continuous(labels = label_percent()) +
      labs(
        title = glue("Percentage of Studies Reporting Results Within Different Time Frames ({faceted_by.label})"),
        #x = "Cut-off date", # use the geom_richtext() to represent x-axis labels
        x = "",              # but still need margins for axis.title.x
        y = "Percentage",
        fill = "Reporting Within Time Frame"
      ) +
      # scale_fill_brewer(type = 'qual', palette = 1, direction = -1) +
      scale_fill_manual(
        values =
            c( "#CDCDCD",  "#E69E86", "#CCDB6F", "#34AF92"),
          # ( if(n.groups == 4)
          #     c( "#CDCDCD",  "#E69E86", "#CCDB6F", "#34AF92")
          #   else
          #     c( "#CDCDCD",  "#CC8181","#E69E86", "#CCDB6F", "#34AF92")
          # )
          # values = c( "#B6B6B6",  "#CCBA5A", "#A7B647", "#12684E")
        ) +
      theme_minimal() +
      theme(
            #axis.text.x = element_text(angle = 45, hjust = 1),
            #axis.text.x = element_markdown(size = 8),
            axis.text.x = element_blank(),
            axis.text.y = element_markdown(size = 8),
            plot.background = element_rect(fill = "white", color = NA),  # Ensure background for text
            strip.placement = "outside",
            strip.text.x.bottom = element_text(margin = margin(t = 20)),  # move facet labels down
            axis.title.x = element_text(
                            margin = (
                              if(is.null(with_facet)) { margin( t = 25 ) }
                              else                    { margin( t = 10 ) }
                            ),
            )
            #panel.spacing.y = unit(40, "pt"),  # add space between plot and strips
      )

    if( !is.null(fig.cb) ) {
      fig <- fig.cb(fig)
    }

    fig
  }
  show(fig.result_reported_within.stacked_area)

  faceted_by.file_part <- gsub('\\.', '-', faceted_by.label)
  plot.output.path.base <- fs::path(glue(
      "figtab/{agg.windows[[1]]$window$prefix}/fig.result_reported_within.facet_{faceted_by.file_part}.stacked_area"))
  fs::dir_create(path_dir(plot.output.path.base))
  for (ext in c("png", "svg", "pdf")) {
    local_opts <- ggsave.opts
    if (ext == "pdf") local_opts[["device"]] <- cairo_pdf
    rlang::inject(
      ggsave(paste0(plot.output.path.base, ".", ext),
             !!!local_opts)
    )
  }
}
# }}}
