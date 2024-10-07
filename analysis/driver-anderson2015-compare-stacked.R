# if(!sys.nframe()) { source('analysis/driver-anderson2015-compare-stacked.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

params <- window.params.read()

plot.compare.anderson2015.agg.window <- function() {
  agg.windows.original <- list(
       anderson2015.original = anderson2015.window.create()
  )

  anderson2015.new.params <- params |>
    window.params.filter.by.name('^anderson2015_2008-2012$') |>
    window.params.apply.prefix('anderson2015.new')
  anderson2015.new.agg.windows <- process.windows.init(anderson2015.new.params) |>
    process.windows.amend.results_reported()
  print(names( anderson2015.new.agg.windows ))
  names(anderson2015.new.agg.windows) <- c('anderson2015.new')
  plot.windows.stacked.chart(agg.windows.original, with_names = TRUE)
  plot.windows.stacked.chart(anderson2015.new.agg.windows, with_names = TRUE)
}


plot.compare.anderson2015.agg.window()
