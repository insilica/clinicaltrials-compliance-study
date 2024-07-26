# clinical_trials_analysis.R

# Load necessary libraries
if (!require("pacman")) install.packages("pacman")
library(pacman)

pacman::p_load(
  arrow,
  dplyr,
  lubridate,
  survival,
  ggplot2,
  survminer,
  ggsurvfit,
  forcats,
  stringr,
  broom,
  tidyr,
  assertthat
)

# Functions to create date from year and month
create_date_w_mfmt <- function(year, month, month_fmt) {
  date_fmt <- paste("%Y", month_fmt, "%d", sep = "-")
  if_else(!is.na(year) & !is.na(month),
          as.Date(paste(year, month, "01", sep = "-"), format = date_fmt),
          NA)
}

create_date_month_name <- function(year, month) {
  create_date_w_mfmt(year, month, "%B")
}

create_date_month_int <- function(year, month) {
  create_date_w_mfmt(year, month, "%m")
}


add_prefix <- function(df, prefix) {
  df %>%
    rename_with(~ paste0(prefix, .))
}

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
           common.masking = schema0.masking,
    )
}

standardize.jsonl_derived <- function(df) {
  df |>
    add_prefix('schema1.')
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
      across(c(schema0.results12), \(x) x == 'Yes'),
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

preprocess_data.common.survival <- function(data, censor_date) {
  data <- data %>%
    # Define the event and time variables
    mutate(
      surv.event = if_else(!is.na(common.results_received_date) & common.results_received_date <= censor_date, 1, 0),
      surv.time_months = pmin(
        interval(common.primary_completion_date_imputed, common.results_received_date) / months(1),
        interval(common.primary_completion_date_imputed, censor_date) / months(1),
        na.rm = TRUE
      )
    )
  return(data)
}

preprocess_data.common.regression <- function(data) {
  # From paper Table 3:
  # Regression models included the following covariates in addition to those
  # listed:
  #   - primary purpose of study,
  #   - enrollment,
  #   - year of study completion,
  #   - study duration,
  #   - number of study groups,
  #   - use of randomized assignment, and
  #   - use of masking.
  split.enrollment <- 32
  split.pc_year <- 2010
  data <- data %>%
    # Define the variables for reporting by a particular time, either by
    mutate(
      # - 12 months or
      rr.results_reported_12mo =
        ( interval(common.primary_completion_date_imputed, common.results_received_date) < months(12) + days(1) ) |>
        replace_na(FALSE),
      # - 5 years.
      rr.results_reported_5yr =
        ( interval(common.primary_completion_date_imputed, common.results_received_date) < years(5) + days(1) ) |>
        replace_na(FALSE),
    ) %>%
    # Phase short names
    mutate(rr.phase =
           fct_recode(common.phase,
                      `1-2` = "Phase 1/Phase 2",
                      `2` = "Phase 2",

                      `2-3` = "Phase 2/Phase 3",
                      `3` = "Phase 3",
                      `4` = "Phase 4",
                      ) |>
           # Turn NA values into "Not applicable" level
           fct_na_value_to_level(level = "Not applicable")
    ) %>%
    mutate(rr.primary_purpose =
           fct_collapse(common.primary_purpose,
                        Other = setdiff(levels(common.primary_purpose),
                                        c("Treatment", "Prevention", "Diagnostic"))) |>
           factor(levels = c('Treatment', 'Prevention', 'Diagnostic', 'Other'))
    ) %>%
    mutate(
           # Impute NA with mean
           enrollment.pre = ifelse(is.na(common.enrollment),
                                   mean(common.enrollment, na.rm = TRUE),
                                   common.enrollment),
           # Replace 0 with a small positive value
           enrollment.pre = ifelse(enrollment.pre == 0, 0.5, enrollment.pre)
    ) |>
    mutate(
           # compare with mntopcom
           rr.study_duration = interval(common.start_date, common.primary_completion_date_imputed) / months(1),
           rr.oversight_is_fda = ifelse(common.oversight == 'United States: Food and Drug Administration',
                                     'Yes', 'No') |>
                             as.factor() |> relevel( ref = 'Yes' ),
           rr.use_of_randomized_assgn = common.allocation == 'Randomized' & common.number_of_arms > 1,
           rr.masking = case_when(
                                  common.allocation == 'Non-Randomized' ~ "Open",
                                  .default = common.masking
                          ) |> as.factor() |> relevel( ref = 'Open' ),
           rr.log2_enrollment_less_split = ifelse(enrollment.pre <= split.enrollment,
                                                  log2(enrollment.pre),
                                                  0),
           rr.log2_enrollment_more_split = ifelse(enrollment.pre > split.enrollment,
                                                  log2(enrollment.pre),
                                                  0),
           rr.pc_year_increase_pre_split = ifelse(common.pc_year_imputed < split.pc_year,
                                                  common.pc_year_imputed - split.pc_year,
                                                  0),
           rr.pc_year_increase_post_split = ifelse(common.pc_year_imputed >= split.pc_year,
                                                   common.pc_year_imputed - split.pc_year,
                                                   0),
    ) |>
    mutate(
           rr.study_duration.clamp = ifelse(rr.study_duration > 24, 24, rr.study_duration)
    ) |>
    mutate(
      rr.sdur.per_3_months_increase_pre_12  = ifelse(rr.study_duration.clamp <= 12, rr.study_duration.clamp / 3, 12 / 3),
      rr.sdur.per_3_months_increase_post_12 = ifelse(rr.study_duration.clamp > 12, (rr.study_duration.clamp - 12) / 3, 0)
    ) |>
    mutate(
      rr.number_of_arms = case_when(
        common.number_of_arms == 1 ~ "one",
        common.number_of_arms == 2 ~ "two",
        common.number_of_arms >= 3 ~ "three or more"
      ) |> as.factor() |> relevel( ref = "one" )
    ) %>%
    mutate(
      rr.intervention_type  = relevel(common.intervention_type, ref = "Drug"      ),
      rr.funding            = relevel(common.funding,           ref = "NIH"       ),
      rr.phase              = relevel(rr.phase,                 ref = "4"         ),
      rr.primary_purpose    = relevel(rr.primary_purpose,       ref = "Treatment" ),
      rr.overall_status     = relevel(common.overall_status,    ref = "Completed" )
    )

  assert_that( data |> subset( schema0.results12 != rr.results_reported_12mo ) |> nrow() == 0,
              msg = 'Original results12 should match computed rr.results_reported_12mo' )

  return(data)
}

preprocess_data.common <- function(data, censor_date) {
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
    preprocess_data.common.regression()

  return(data)
}

# Function to fit the Kaplan-Meier models
create_survfit_models <- function(data) {
  list(
    fit.funding       = survfit2(Surv(surv.time_months, surv.event) ~ common.funding,
                                 data = data, start.time = 0),
    fit.phase         = survfit2(Surv(surv.time_months, surv.event) ~ common.phase.norm,
                                 data = data, start.time = 0),
    fit.interventions = survfit2(Surv(surv.time_months, surv.event) ~ common.intervention_type,
                                 data = data, start.time = 0),
    fit.status        = survfit2(Surv(surv.time_months, surv.event) ~ common.overall_status,
                                 data = data, start.time = 0)
  )
}

# Function to plot Kaplan-Meier curves
plot_survfit <- function(fit, breaks.fig, breaks.risktable.less_than) {
  fit |>
    ggsurvfit(type = 'risk') +
    add_risktable(times = breaks.risktable.less_than,
                  risktable_stats = c("n.risk")) +
    scale_ggsurvfit(x_scales = list(breaks = breaks.fig),
                    y_scales = list(limits = c(0, 1))) +
    xlab("Months after primary completion date")
}


logistic_regression <- function(data) {
  ##+ mntopcom # weird that this has more exact values?
  model <- glm( rr.results_reported_12mo ~
               ( rr.primary_purpose
               + rr.intervention_type
               + rr.phase
               + rr.oversight_is_fda
               + rr.funding
               + rr.log2_enrollment_less_split + rr.log2_enrollment_more_split
               + rr.overall_status
               + rr.pc_year_increase_pre_split + rr.pc_year_increase_post_split
               + rr.sdur.per_3_months_increase_pre_12 + rr.sdur.per_3_months_increase_post_12
               + rr.number_of_arms
               + rr.use_of_randomized_assgn
               + rr.masking
               ),
               data = data, family = binomial )
  model <- tidy(model, exponentiate = TRUE, conf.int = TRUE)
  return(model)
}

cox_regression <- function(data) {
  model <- coxph(Surv(time_months, event) ~ intervention_type + phase.norm + funding + overall_status, data = data)
  tidy(model, exponentiate = TRUE, conf.int = TRUE)
}
