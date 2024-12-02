# source('analysis/driver-anderson2015-regression.R')

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger, purrr, dplyr, stringr, ggplot2 )

source('analysis/ctgov.R')

### INPUT & PREPROCESS
hlact.studies <- anderson2015.read_and_process()

assertion.anderson2015.results12(hlact.studies)

### REGRESSION MODELS
model.logistic <- logistic_regression(hlact.studies, formula.anderson2015)

model.logistic |> str.print(n = 50) |> log_info(); NA

window <- anderson2015.window()
start_date <- window$date$start
stop_date  <- window$date$stop
# Censoring date
censor_date <- window$date$cutoff
jsonl.studies <- arrow::read_parquet('brick/analysis-20130927/ctgov-studies-hlact.parquet') |>
  tibble()
log_info(str.print(jsonl.studies))#DEBUG

jsonl.studies <- standardize.jsonl_derived(jsonl.studies) |>
  preprocess_data.common(start_date  = start_date,
                         stop_date   = stop_date,
                         censor_date = censor_date)

model.logistic.jsonl <- logistic_regression(jsonl.studies, formula.jsonl_derived)

model.logistic.jsonl |> str.print(n = 50 ) |> log_info(); NA

or.combined <- compare.model.logistic(model.logistic.jsonl)


or.df <- compare.model.df(model.logistic.jsonl)
or.df <- compare.model.df(model.logistic)
or.df |> with(cor(or.model, or.paper))
plot.blandr.or.df(or.df)

fig.compare.logistic <- plot.compare.logistic(or.combined)
show(fig.compare.logistic)
plot.output.base <- "figtab/anderson2015/compare.table_s7.or"
for (ext in c("png", "svg", "pdf")) {
  ggsave(paste0(plot.output.base, ".", ext), width = 12, height = 8)
}
