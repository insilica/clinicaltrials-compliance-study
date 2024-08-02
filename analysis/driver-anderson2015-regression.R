if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( purrr, dplyr, stringr, ggplot2 )

source('analysis/ctgov.R')

### INPUT
hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
  tibble()
print(hlact.studies)#DEBUG
# Censoring date
censor_date <- as.Date("2013-09-27")

### PREPROCESS
hlact.studies <- standardize.anderson2015(hlact.studies) |>
  preprocess_data.common(censor_date)

assertion.anderson2015.results12(hlact.studies)

### REGRESSION MODELS
model.logistic <- logistic_regression(hlact.studies, formula.anderson2015)

model.logistic |> print(n = 50 ); NA

jsonl.studies <- arrow::read_parquet('brick/analysis-20130927/ctgov-studies-hlact.parquet') |>
  tibble()
print(jsonl.studies)#DEBUG

jsonl.studies <- standardize.jsonl_derived(jsonl.studies) |>
  preprocess_data.common(censor_date)

model.logistic.jsonl <- logistic_regression(jsonl.studies, formula.jsonl_derived)

model.logistic.jsonl |> print(n = 50 ); NA

or.combined <- compare.model.logistic(model.logistic.jsonl)


compare.model.logistic.or( model.logistic ) |>
  select( term, or)  |>
  inner_join(
             compare.model.logistic.or.paper() |> select( term, or ),
             by = 'term',
             suffix = c('.model', '.paper')
             ) |>
  ( \(x) { cor(x$or.model, x$or.paper) } )()


fig.compare.logistic <- plot.compare.logistic(or.combined)
show(fig.compare.logistic)
ggsave("figtab/anderson2015/compare.table_s7.or.png", width = 12, height = 8)
