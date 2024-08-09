# argv <- c('params.yaml', 'sliding-window'); source('analysis/driver-sliding.R')

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger, rlang, purrr, fs, dplyr, stringr, ggplot2, yaml, patchwork )

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
    + labs(x = 'cut-off date', y = 'Percentage')
    + ggtitle(title)
    + theme_minimal()
  )

  return(fig)
}

(  plot.pct.scatterline(df, rr.results_reported_12mo.pct,
                      'Percentage results reported within 12 months')
 + plot.pct.scatterline(df, rr.results_reported_5yr.pct,
                       'Percentage results reported within 5 years')
 + plot.pct.scatterline(df, hlact.pct,
                       'Percentage HLACTs out of all studies')
)

stop()

for(name in names(models.logistic)) {
  model <- models.logistic[[name]]
  log_info(name)
  log_info(model)
  fig <- compare.model.logistic( model ) |>
    plot.compare.logistic()
  fig <- fig + labs(title = name )
  show(fig)
  #invisible(readline(prompt="Press [enter] to continue"))
  plot.output.path <- fs::path(glue("figtab/{name}/compare.table_s7.or.png"))
  fs::dir_create(path_dir(plot.output.path))
  ggsave(plot.output.path, width = 12, height = 8)
}
