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

### REGRESSION MODELS
model.logistic <- logistic_regression(hlact.studies)
model.logistic |> print(n = 50 ); NA

or.combined <- compare.model.logistic(model.logistic)

fig.compare.logistic <- plot.compare.logistic(or.combined)
show(fig.compare.logistic)
ggsave("figtab/anderson2015/compare.table_s7.or.png", width = 12, height = 8)
