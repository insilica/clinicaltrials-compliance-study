# argv <- c('params.yaml', 'sliding-window'); source('analysis/driver-sliding.R')

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load(
               dplyr,
               forcats,
               fs,
               ggplot2,
               glue,
               logger,
               patchwork,
               purrr,
               rlang,
               scales,
               stringr,
               yaml
)

log_layout(layout_glue_colors)
log_threshold(TRACE)
#log_threshold(DEBUG)

source('analysis/ctgov.R')

if(!exists('argv')) {
  argv <- commandArgs(trailingOnly = TRUE)
}

if (length(argv) != 2) {
  stop("Usage: script.R <path_to_yaml_file> <key_to_search>", call. = FALSE)
}

params_file <- argv[1]
prefix      <- argv[2]

params <- yaml.load_file(params_file)

windows <- params$param |>
  keep( \(x) !is.null(x$prefix) && x$prefix == prefix )

if( length(windows) == 0 ) {
  stop("No windows!")
}

agg.windows <- list()

for(w_name in names(windows)) {
  window <- windows[[w_name]]
  censor_date <- window$date$cutoff

  log_info(w_name)

  agg.windows[[w_name]]$window <- window

  all.path   <- window$output$all
  hlact.path <- window$output$`hlact-filtered`

  agg.windows[[w_name]] <- within(agg.windows[[w_name]],{
    all.studies <- arrow::read_parquet(all.path)

    hlact.studies <- arrow::read_parquet(hlact.path) |>
      tibble()

    hlact.studies <-
      standardize.jsonl_derived(hlact.studies) |>
      preprocess_data.common(start_date  = window$date$start,
                             stop_date   = window$date$stop,
                             censor_date = censor_date)

    model.logistic <-
      logistic_regression(hlact.studies,
                          formula.jsonl_derived)
  })
}

for(w_name in names(agg.windows)) {
  agg.windows[[w_name]] <- within(agg.windows[[w_name]], {
    all.studies.n <- nrow(all.studies)
    hlact.studies.n <- nrow(hlact.studies)
    surv.event.n <- sum(hlact.studies$surv.event)
    rr.results_reported_12mo.n <- sum(hlact.studies$rr.results_reported_12mo)
    rr.results_reported_5yr.n  <- sum(hlact.studies$rr.results_reported_5yr )
  })
}

df <- agg.windows |>
  map( ~ data.frame(
           cutoff = .x$window$date$cutoff,
           hlact.n    = .x$hlact.studies.n,
           hlact.pct  = .x$hlact.studies.n / .x$all.studies.n,
           rr.results_reported_12mo.n   =
             .x$rr.results_reported_12mo.n,
           rr.results_reported_12mo.pct =
             .x$rr.results_reported_12mo.n / .x$hlact.studies.n,
           rr.results_reported_5yr.n   =
             .x$rr.results_reported_5yr.n,
           rr.results_reported_5yr.pct =
             .x$rr.results_reported_5yr.n / .x$hlact.studies.n
           ) ) |>
  list_rbind() |> tibble()
df

plot.pct.scatterline <- function(data, y.var, title) {
  fig <- ( ggplot(df, aes(x = cutoff, y = {{y.var}}, group = 1))
    + geom_line()
    + geom_point( size = 2)
    + scale_y_continuous()
    + labs(x = 'Cut-off date', y = 'Percentage')
    + ggtitle(title)
    + theme_minimal()
  )

  return(fig)
}

fig.pct.all <-
(  plot.pct.scatterline(df, rr.results_reported_12mo.pct,
                      'Percentage results reported within 12 months')
 + plot.pct.scatterline(df, rr.results_reported_5yr.pct,
                       'Percentage results reported within 5 years')
 + plot.pct.scatterline(df, hlact.pct,
                       'Percentage HLACTs out of all studies')
)
show(fig.pct.all)
plot.output.path <- fs::path(glue("figtab/{window$prefix}/fig.percentage.all.png"))
fs::dir_create(path_dir(plot.output.path))
ggsave(plot.output.path)

for(name in names(agg.windows)) {
  with(agg.windows[[name]],{
    model <- model.logistic
    log_info(name)
    log_info(str.print(model))
    fig <- compare.model.logistic( model ) |>
      plot.compare.logistic()
    fig <- fig + labs(title = name)
    show(fig)
    #invisible(readline(prompt="Press [enter] to continue"))
    plot.output.path <- fs::path(glue("figtab/{window$prefix}/{window$suffix}/compare.table_s7.or.png"))
    fs::dir_create(path_dir(plot.output.path))
    ggsave(plot.output.path, width = 12, height = 8)
  })
}


for(w_name in names(windows)) {
  agg.windows[[w_name]]$agg.interval.groups <-
    agg.windows[[w_name]]$hlact.studies |>
  mutate( agg.interval =
            interval(common.primary_completion_date_imputed, common.results_received_date),
       ) |>
  mutate( agg.results_reported_within = case_when(
             is.na(int_length(agg.interval)) ~ 'No results',
             agg.interval < months(1*12) + days(1) ~ glue('{1*12} months'),
             agg.interval < months(2*12) + days(1) ~ glue('{2*12} months'),
             agg.interval < months(3*12) + days(1) ~ glue('{3*12} months'),
             agg.interval < months(4*12) + days(1) ~ glue('{4*12} months'),
             agg.interval < months(5*12) + days(1) ~ glue('{5*12} months'),
             TRUE                                  ~ glue('{5*12}+ months')
          ) |> as.factor()
       ) |>
  group_by( agg.results_reported_within ) |>
  summarize( agg.results_reported_within.count = n() ) |>
  mutate( agg.results_reported_within.pct =
           agg.results_reported_within.count / sum(agg.results_reported_within.count) )
}

windows.result_reported_within <-
  agg.windows |>
  map( ~ .x$agg.interval.groups |>
      mutate( cutoff = .x$window$date$cutoff ) ) |>
  list_rbind()


fig.result_reported_within.stacked_area <-
  ggplot(
         windows.result_reported_within |>
           mutate(
              time = as.character(cutoff),
              pct  = agg.results_reported_within.pct,
              grp  = forcats::fct_rev(agg.results_reported_within)
           ),
         aes(x = time, y = pct, fill = grp) ) +
    geom_bar(stat = "identity") +
    geom_text(aes(label = ifelse(pct > 0.01, sprintf("%.1f%%", 100*pct), '')),
              position = position_stack(vjust = 0.5), size = 4,
              #color = "black"
              ) +
    scale_y_continuous(labels = label_percent()) +
    labs(
      title = "Percentage of Studies Reporting Results Within Different Time Frames",
      x = "Cut-off date",
      y = "Percentage",
      fill = "Reporting Within Time Frame"
    ) +
    scale_fill_brewer(type = 'qual', palette = 1, direction = -1) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
show(fig.result_reported_within.stacked_area)
plot.output.path <- fs::path(glue("figtab/{window$prefix}/fig.result_reported_within.stacked_area.png"))
fs::dir_create(path_dir(plot.output.path))
ggsave(plot.output.path)
