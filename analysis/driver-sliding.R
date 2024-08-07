# source('analysis/driver-sliding.R')

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( purrr, fs, dplyr, stringr, ggplot2 )

source('analysis/ctgov.R')

# TODO remove this hack and read from the parameter file
dirs <- fs::dir_ls('brick', type='directory') |>
  keep(~ grepl('sliding-window', .x)) |>
  sort()

models.logistic <- list()

for(dir in dirs) {
  # TODO remove this hack and read from the parameter file
  name <- fs::path_file(dir)
  censor_date <- dir |> str_extract('\\d{8}$') |> ymd()

  print(dir)#DEBUG
  print(name)#DEBUG
  print(censor_date)#DEBUG

  all.path   <- path_join(c(dir, 'ctgov-studies-all.parquet'  ))
  hlact.path <- path_join(c(dir, 'ctgov-studies-hlact.parquet'))

  jsonl.studies <- arrow::read_parquet(hlact.path) |>
    tibble()

  jsonl.studies <- standardize.jsonl_derived(jsonl.studies) |>
    preprocess_data.common(censor_date)

  model.logistic <- logistic_regression(jsonl.studies, formula.jsonl_derived)
  models.logistic[[name]] <- models.logistic
  #print(jsonl.studies)#DEBUG

}

for(name in names(models.logistic)) {
  model <- models.logistic[[name]]
  print(name)
  print(model)
  fig <- compare.model.logistic( model ) |>
    plot.compare.logistic()
  fig <- fig + labs(title = name )
  show(fig)
  #invisible(readline(prompt="Press [enter] to continue"))
  plot.output.path <- fs::path(glue("figtab/{name}/compare.table_s7.or.png"))
  fs::dir_create(path_dir(plot.output.path))
  ggsave(plot.output.path, width = 12, height = 8)
}
