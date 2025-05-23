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

params <- window.params.read( params_file = params_file )
windows <- window.params.filter.by.prefix(params, prefix)

agg.windows <- process.windows.init(windows) |>
  process.windows.amend.results_reported()

windows.rdata.write(glue('brick/{prefix}_processed'),
                    agg.windows)
windows.hlact.write(glue('brick/{prefix}_processed'),
                    agg.windows)
