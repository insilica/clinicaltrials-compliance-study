preprocess_data.common <- function(data, start_date, stop_date, censor_date) {
  start_date  <- as.Date(start_date)
  stop_date   <- as.Date(stop_date)
  censor_date <- as.Date(censor_date)
  data <- data |>
    # Normalize phases
    mutate(common.phase.norm =
           # Normalize 1: Merge phases
           fct_recode(common.phase,
                      `Phase 1/2 & 2` = "Phase 1/Phase 2",
                      `Phase 1/2 & 2` = "Phase 2",

                      `Phase 2/3 & 3` = "Phase 2/Phase 3",
                      `Phase 2/3 & 3` = "Phase 3",
                      ) |>
           # Normalize 2: Turn NA values into "N/A" level
           fct_na_value_to_level(level = "N/A")
    ) |>
    mutate(
      common.pc_year_imputed = year(common.primary_completion_date_imputed),
    ) |>
    preprocess_data.common.survival(censor_date) |>
    preprocess_data.common.regression(start_date, stop_date) |>
    preprocess_data.common.reporting()

  return(data)
}

preprocess_data.common.reporting <- function(data) {
  data <- data |>
    # Define the variables for reporting by a particular time, either by
    mutate(
      # - 12 months or
      cr.results_reported_12mo =
	dateproc.results_reported.within_inc(pick(everything()), months(12)),
      # - 36 months
      cr.results_reported_36mo =
	dateproc.results_reported.within_inc(pick(everything()), months(36)),

      cr.months_to_results_no_censor =
        interval(common.primary_completion_date_imputed, common.results_received_date) / months(1)
    )
  return(data)
}
