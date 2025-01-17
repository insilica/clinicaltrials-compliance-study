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
    preprocess_data.common.reporting() |>
    preprocess_data.common.survival(censor_date) |>
    preprocess_data.common.regression(start_date, stop_date)

  return(data)
}

preprocess_data.common.reporting <- function(data) {
  data <- data |>
    mutate(
      # This ignores extensions and only looks at the standard deadline per
      # §11.44(a). This is 1 year after the completion date.
      #
      #   results date - completion date < 1 year
      # .
      cr.interval_to_results_no_extensions_no_censor =
        interval(common.primary_completion_date_imputed, common.results_received_date),

      # This applies the extension if it exists.
      # Per §11.44(b)(2) which allows for a 2 year delay after the date the
      # certification is submitted.
      #
      # To make sure that we have an equivalent interval:
      #
      #   results date - (disp submit date + 1 year) < 1 year
      # .
      cr.interval_to_results_with_extensions_no_censor =
        ifelse(common.delayed,
          interval(common.disp_submit_date + years(1), common.results_received_date),
          cr.interval_to_results_no_extensions_no_censor
        ),
    ) |>
    # Compute how many months
    mutate(
      cr.months_to_results_no_extensions_no_censor =
        time_length(cr.interval_to_results_no_extensions_no_censor, "months"),

      cr.months_to_results_with_extensions_no_censor =
        time_length(cr.interval_to_results_with_extensions_no_censor, "months"),
    ) |>
    # Define the variables for reporting by a particular time, either by
    mutate(
      # Which type of intervalue to use for the `dateproc.results_reported.within_inc()`
      # computation below:
      cr.interval_to_results_default = cr.interval_to_results_no_extensions_no_censor,
      # - 12 months or
      cr.results_reported_12mo =
	dateproc.results_reported.within_inc(pick(everything()), months(12)),
      # - 36 months
      cr.results_reported_36mo =
	dateproc.results_reported.within_inc(pick(everything()), months(36)),
    )
  return(data)
}
