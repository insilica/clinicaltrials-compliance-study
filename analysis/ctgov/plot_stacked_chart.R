
#### Plot stacked chart of intervals {{{

categorize_intervals <- function(interval_length, breakpoints) {
  labels <- c(paste0(breakpoints, " months"),
              paste0(max(breakpoints), "+ months"))

  # Create bins for cut() function including an Inf for the upper bound of the last interval
  bins <- c(-Inf, as.numeric(months(breakpoints) + days(1)), Inf)

  # Vectorized interval categorization using if_else and cut
  result <- if_else(
    is.na(interval_length),
    "No results",
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

# plot.windows.stacked.chart(agg.windows)
plot.windows.stacked.chart <-
    function(agg.windows,
             with_names = FALSE,
             with_facet = "common.funding" ) {

  faceted_by.label <- with_facet
  if( is.null(with_facet) ) {
    faceted_by.label <- 'overall'
  }
  faceted_by.label <- gsub("^common\\.", "", faceted_by.label)

  for(w_name in names(agg.windows)) {
    agg.windows[[w_name]] <- agg.windows[[w_name]] |>
      process.single.agg.window.amend.agg.interval.groups(
        with_facet = with_facet
      )
  }
  agg.windows[[1]]$agg.interval.groups |> names()

  #agg.windows |>
  #  map( ~ .x$agg.interval.groups |> print() )

  windows.result_reported_within <-
    agg.windows |>
    map( ~ .x$agg.interval.groups |>
        mutate(start  = .x$window$date$start,
               stop   = .x$window$date$stop,
               cutoff = .x$window$date$cutoff,)) |>
    list_rbind()

  fig.result_reported_within.stacked_area <- {
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
    if( with_names ) {
      time.label.glue_format <- "{.y}\n  {start}\n–{stop}\n({cutoff})"
    } else {
      time.label.glue_format <- "  {start}\n–{stop}\n({cutoff})"
    }
    time.label <- agg.windows |>
      imap_chr( ~ with(.x$window$date, {
                    glue(time.label.glue_format)
               })) |> unname()
    count.label.df <- df |>
      group_by(across(c(
                        (if(!is.null(with_facet)) "facet" ),
                        "start",
                        "stop",
                        "cutoff"))) |>
      summarize(n = sum(agg.results_reported_within.count)) |>
      mutate(
           label = glue("n = {n}"),
      ) |> ungroup() |>
      select(c(
                  (if(!is.null(with_facet)) "facet" ),
                  "cutoff",
                  "label"))

    fig <- ggplot(df,
           aes(x = time, y = pct, fill = grp) )

    if(!is.null(with_facet)) {
      fig <- fig + facet_wrap(~ facet, strip.position = "bottom")
    }

    fig <- fig +
      geom_bar(stat = "identity") +
      geom_text(aes(label = ifelse(pct > 0.01, sprintf("%1.0f%%", 100*pct), '')),
                position = position_stack(vjust = 0.5), size = 6, family='mono',
                color = "black" # "#fdfdfd" "black"
                ) +
      geom_text(data = count.label.df,
                aes(x = cutoff, y = 0, label = label),
                #position = position_dodge(width = 0.9),
                #vjust = 3.5,
                #vjust = 4.0,
                vjust = 2.0,
                size = 4,
                inherit.aes=FALSE) +
      scale_x_discrete(labels = time.label) +
      scale_y_continuous(labels = label_percent()) +
      labs(
        title = glue("Percentage of Studies Reporting Results Within Different Time Frames ({faceted_by.label})"),
        x = "Cut-off date",
        y = "Percentage",
        fill = "Reporting Within Time Frame"
      ) +
      # scale_fill_brewer(type = 'qual', palette = 1, direction = -1) +
      scale_fill_manual(
        values = c( "#CDCDCD",  "#E69E86", "#CCDB6F", "#34AF92")
        # values = c( "#CDCDCD",  "#CC8181","#E69E86", "#CCDB6F", "#34AF92")
        # values = c( "#B6B6B6",  "#CCBA5A", "#A7B647", "#12684E")
        ) +
      theme_minimal() +
      theme(axis.text.x = element_text(size = 8))+
      theme(axis.text.y = element_text(size = 8)) 
      #theme(axis.text.x = element_text(angle = 45, hjust = 1))

    fig
  }
  show(fig.result_reported_within.stacked_area)

  faceted_by.file_part <- gsub('\\.', '-', faceted_by.label)
  plot.output.path <- fs::path(glue(
      "figtab/{agg.windows[[1]]$window$prefix}/fig.result_reported_within.facet_{faceted_by.file_part}.stacked_area.png"))
  fs::dir_create(path_dir(plot.output.path))
  ggsave(plot.output.path, width = 12, height = 8)
}
# }}}

plot.windows.stacked.chart(agg.windows, with_facet=NULL)
