# if(!sys.nframe()) { source('analysis/driver-anderson2015-compare-stacked.R') }

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

source('analysis/ctgov.R')

params_file <- 'params.yaml'
params <- yaml.load_file(params_file)

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
