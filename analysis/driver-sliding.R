# if(!sys.nframe()) { argv <- c('params.yaml', 'sliding-window'); source('analysis/driver-sliding.R') }
# if(!sys.nframe()) { argv <- c('params.yaml', 'long-observe'  ); source('analysis/driver-sliding.R') }
# if(!sys.nframe()) { argv <- c('params.yaml', 'yearly_obs36'  ); source('analysis/driver-sliding.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

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

agg.windows <- windows.rdata.read(glue('brick/{prefix}_processed'))

plot.windows.pct.scatterline(agg.windows)

if( FALSE ) {

agg.windows <- agg.windows |>
  process.windows.amend.model.logistic()
plot.windows.compare.logistic(agg.windows)

}

plot.windows.stacked.chart(agg.windows)

plot.windows.stacked.chart(agg.windows, with_facet = NULL)
