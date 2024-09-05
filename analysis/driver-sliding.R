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
