if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger, purrr, dplyr, stringr, ggplot2 )

source('analysis/ctgov.R')

### INPUT
hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
  tibble()
log_info(str.print(hlact.studies))#DEBUG
start_date <- as.Date('2008-01-01')
stop_date  <- as.Date('2012-09-01')
# Censoring date
censor_date <- as.Date("2013-09-27")

### PREPROCESS
hlact.studies <- standardize.anderson2015(hlact.studies) |>
  preprocess_data.common(start_date  = start_date,
                         stop_date   = stop_date,
                         censor_date = censor_date)

assertion.anderson2015.results12(hlact.studies)

### REGRESSION MODELS
model.logistic <- logistic_regression(hlact.studies, formula.anderson2015)

model.logistic |> str.print(n = 50) |> log_info(); NA

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


or.df <- compare.model.logistic.or( model.logistic ) |>
  select( term, or)  |>
  inner_join(
             compare.model.logistic.or.paper() |> select( term, or ),
             by = 'term',
             suffix = c('.model', '.paper')
             )

or.df |> with(cor(or.model, or.paper))

pacman::p_load( blandr )

blandr::blandr.draw(method1 = or.df$or.paper,
                    method1name = 'Paper',
                    method2 = or.df$or.model,
                    method2name = 'Model')

fig.compare.logistic <- plot.compare.logistic(or.combined)
show(fig.compare.logistic)
ggsave("figtab/anderson2015/compare.table_s7.or.png", width = 12, height = 8)
