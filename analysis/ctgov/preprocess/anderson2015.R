standardize.anderson2015 <- function(df) {
  df |> add_prefix('schema0.')       |>
    standardize.anderson2015.type()  |>
    standardize.anderson2015.dates() |>
    standardize.anderson2015.norm()  |>
    mutate(
           common.phase = schema0.phase,
           common.overall_status = schema0.overall_statusc,
           common.funding = schema0.funding,
           common.primary_purpose = schema0.primary_purpose,
           common.enrollment = schema0.ENROLLMENT,

           # This is only defined in schema0.
           common.oversight = schema0.oversight,

           common.allocation = schema0.allocation,
           common.number_of_arms = schema0.NUMBER_OF_ARMS,
           common.masking = schema0.masking,

           common.delayed = schema0.delayed,
    )
}

standardize.anderson2015.type <- function(data) {
  data <- data |>
    rename(schema0.nct_id = schema0.NCT_ID) %>%
    mutate(
      # These are all factor variables.
      across(c(schema0.phase, schema0.overall_statusc,
               schema0.funding, schema0.primary_purpose,
               schema0.oversight, schema0.RESPONSIBLE_PARTY_TYPE,
               schema0.allocation, schema0.masking), as.factor),
      # These are numeric.
      across(c(schema0.mntopcom), as.numeric),
      # These are integers.
      across(c(schema0.ENROLLMENT), as.integer),
      # Interventions are stored as { "Yes",  "No" }
      across(c(schema0.behavioral,
               schema0.biological,
               schema0.device,
               schema0.dietsup,
               schema0.drug,
               schema0.genetic,
               schema0.procedure,
               schema0.radiation,
               schema0.otherint), \(x) x == 'Yes'),
      # results12 is stored as { "Yes",  "No" }
      across(c(schema0.results12,
               schema0.delayed,
               schema0.delayed12), \(x) x == 'Yes'),
    )
  return(data)
}

standardize.anderson2015.dates <- function(data) {
  data <- data |>
    # Create the primary completion date based on the given priority
    mutate(common.primary_completion_date_imputed = coalesce(
      create_date_month_name(schema0.p_completion_year, schema0.p_completion_month),
      create_date_month_name(  schema0.completion_year,   schema0.completion_month),
      create_date_month_name(schema0.verification_year, schema0.verification_month)
    )) |>
    # Convert results_received_date to Date object
    mutate(common.results_received_date =
           create_date_month_int(schema0.resultsreceived_year, schema0.resultsreceived_month)
    ) |>
    mutate(
           common.start_date = create_date_month_name(schema0.start_year, schema0.start_month),
           common.disp_submit_date = as.Date(schema0.dr_received_dt),
    )
  return(data)
}

standardize.anderson2015.norm <- function(data) {
  data <- data %>%
    # Normalize by intervention type
    # biological/device/drug/genetic/radiation intervention
    mutate(common.intervention_type =
           case_when(
                     schema0.device     ~ "Device",
                     schema0.biological ~ "Biological",
                     schema0.drug       ~ "Drug",
                     .default           = "Other"
                     ) %>%
           # match factor level order used in paper
           factor(levels = c("Device", "Biological", "Drug", "Other"))
    )
  return(data)
}

assertion.anderson2015.results12 <- function(data) {
  assert_that( data |> subset( schema0.results12 != rr.results_reported_12mo ) |> nrow() == 0,
              msg = 'Original results12 should match computed rr.results_reported_12mo' )
}
