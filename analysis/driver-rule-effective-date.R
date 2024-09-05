# if(!sys.nframe()) { source('analysis/driver-rule-effective-date.R') }

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
