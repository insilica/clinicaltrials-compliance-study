# if(!sys.nframe()) { source('analysis/driver-rule-effective-date.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

params <- window.params.read()

process.compare.rule_effective.agg.window <- function() {
  params.filtered <- params |>
    window.params.filter.by.name('^rule-effective-date-(before|after)$') |>
    window.params.apply.prefix('rule-effective')
  print(names(params.filtered))
  agg.windows <- process.windows.init(params.filtered) |>
    process.windows.amend.results_reported()
  return(agg.windows)
}

agg.window.compare.rule_effective <- process.compare.rule_effective.agg.window()
plot.windows.stacked.chart(agg.window.compare.rule_effective, with_names = TRUE)
plot.windows.stacked.chart(agg.window.compare.rule_effective, with_names = TRUE, with_facet = NULL)
