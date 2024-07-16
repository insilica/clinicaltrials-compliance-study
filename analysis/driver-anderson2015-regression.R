if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( purrr )

source('analysis/lib-anderson2015.R')

### INPUT
hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
  tibble()
print(hlact.studies)#DEBUG
# Censoring date
censor_date <- as.Date("2013-09-27")

### PREPROCESS
hlact.studies <- preprocess_data(hlact.studies, censor_date)

### REGRESSION MODELS
models.logistic <- logistic_regression(hlact.studies)
models.logistic |> walk( \(x) print(x, n = 50 ) ); NA
