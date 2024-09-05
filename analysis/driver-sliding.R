# if(!sys.nframe()) { argv <- c('params.yaml', 'sliding-window'); source('analysis/driver-sliding.R') }
# if(!sys.nframe()) { argv <- c('params.yaml', 'long-observe'  ); source('analysis/driver-sliding.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load(
               assertthat,
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

agg.windows <- process.windows.init(windows) |>
  process.windows.amend.results_reported()

plot.windows.pct.scatterline(agg.windows)

if( FALSE ) {

agg.windows <- agg.windows |>
  process.windows.amend.model.logistic()
plot.windows.compare.logistic(agg.windows)

}

plot.windows.stacked.chart(agg.windows)

plot.windows.stacked.chart(agg.windows, with_facet = NULL)

plot.compare.anderson2015.agg.window <- function() {
  anderson2015.original <- list(
    window        = anderson2015.window(),
    hlact.studies = anderson2015.read_and_process()
  )
  anderson2015.original$window['prefix'] <- 'anderson2015.original'
  agg.windows.original <- list(
       anderson2015.original = anderson2015.original
  )
  anderson2015.new.windows <- params$param['anderson2015_2008-2012']
  anderson2015.new.agg.windows <- process.windows.init(anderson2015.new.windows) |>
    process.windows.amend.results_reported()
  anderson2015.new.agg.windows[[1]]$window$prefix <- 'anderson2015.new'
  print(names( anderson2015.new.agg.windows ))
  names(anderson2015.new.agg.windows) <- c('anderson2015.new')
  plot.windows.stacked.chart(agg.windows.original, with_names = TRUE)
  plot.windows.stacked.chart(anderson2015.new.agg.windows, with_names = TRUE)
}


plot.compare.anderson2015.agg.window()

process.compare.rule_effective.agg.window <- function() {
  windows <- params$param[
               grepl('^rule-effective-date-(before|after)$',
                     names(params$param),
                     perl = TRUE )
             ]
  for(w_name in names(windows)) {
    windows[[w_name]]$prefix <- 'rule-effective'
  }
  print(names(windows))
  agg.windows <- process.windows.init(windows) |>
    process.windows.amend.results_reported()
  return(agg.windows)
}

agg.window.compare.rule_effective <- process.compare.rule_effective.agg.window()
plot.windows.stacked.chart(agg.window.compare.rule_effective, with_names = TRUE)
plot.windows.stacked.chart(agg.window.compare.rule_effective, with_names = TRUE, with_facet = NULL)

plot.compare.rule_effective.agg.window()
