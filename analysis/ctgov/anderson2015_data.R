anderson2015.window <- function() {
  date <- list(
    start  = as.Date('2008-01-01'),
    stop   = as.Date('2012-09-01'),
    # Censoring date
    cutoff = as.Date("2013-09-27")
  )
  window <- list( date = date )
  return(window)
}

anderson2015.read_raw <- function() {
  hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
    tibble()
  log_info(str.print(hlact.studies))#DEBUG
  return(hlact.studies)
}

anderson2015.read_and_process <- function() {
  hlact.studies <- anderson2015.read_raw()

  window <- anderson2015.window()

  ### PREPROCESS
  hlact.studies <- standardize.anderson2015(hlact.studies) |>
    preprocess_data.common(start_date  = window$date$start,
                           stop_date   = window$date$stop,
                           censor_date = window$date$cutoff)

  return(hlact.studies)
}
