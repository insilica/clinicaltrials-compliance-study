#
if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

params <- window.params.read()

process.postrule.agg.window <- function() {
  params.filtered <- params |>
    window.params.filter.by.name('^post-rule-to-20240430$')
  print(names(params.filtered))
  agg.windows <- process.windows.init(params.filtered) |>
    process.windows.amend.results_reported() |>
    process.windows.amend.compliance_extensions()
  return(agg.windows)
}

agg.window.postrule <- process.postrule.agg.window()

windows.rdata.write('brick/post-rule-to-20240430_processed', agg.window.postrule)
windows.hlact.write('brick/post-rule-to-20240430_processed', agg.window.postrule)
