preprocess_data.common <- function(data, start_date, stop_date, censor_date) {
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
    preprocess_data.common.regression(start_date, stop_date)

  return(data)
}
