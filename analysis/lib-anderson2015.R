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

# Function to preprocess data

preprocess_data.anderson2015.type <- function(data) {
  data <- data |>
    rename(nct_id = NCT_ID) %>%
    mutate(
      # These are all factor variables.
      across(c(phase, overall_statusc,
               funding, primary_purpose,
               oversight, RESPONSIBLE_PARTY_TYPE,
               allocation, masking), as.factor),
      # These are numeric.
      across(c(mntopcom), as.numeric),
      # These are integers.
      across(c(ENROLLMENT), as.integer),
      # Interventions are stored as { "Yes",  "No" }
      across(c(behavioral, biological, device, dietsup, drug, genetic, procedure, radiation, otherint), \(x) x == 'Yes'),
      # results12 is stored as { "Yes",  "No" }
      across(c(results12), \(x) x == 'Yes'),
    )
  return(data)
}

preprocess_data.anderson2015.dates <- function(data) {
  data <- data %>%
    # Create the primary completion date based on the given priority
    mutate(primary_completion_date_imputed = coalesce(
      create_date_month_name(p_completion_year, p_completion_month),
      create_date_month_name(  completion_year,   completion_month),
      create_date_month_name(verification_year, verification_month)
    )) %>%
    # Convert results_received_date to Date object
    mutate(results_received_date =
           create_date_month_int(resultsreceived_year, resultsreceived_month)
    ) %>%
    mutate(
           start_date = create_date_month_name(start_year, start_month),
           pc_year_imputed = year(primary_completion_date_imputed),
    )
  return(data)
}

preprocess_data.anderson2015.norm <- function(data) {
  data <- data %>%
    # Normalize phases
    mutate(phase.norm =
           # Normalize 1: Merge phases
           fct_recode(phase,
                      `Phase 1/2 & 2` = "Phase 1/Phase 2",
                      `Phase 1/2 & 2` = "Phase 2",

                      `Phase 2/3 & 3` = "Phase 2/Phase 3",
                      `Phase 2/3 & 3` = "Phase 3",
                      ) |>
           # Normalize 2: Turn NA values into "N/A" level
           fct_na_value_to_level(level = "N/A")
    ) %>%
    # Normalize by intervention type
    # biological/device/drug/genetic/radiation intervention
    mutate(intervention_type =
           case_when(
                     device     ~ "Device",
                     biological ~ "Biological",
                     drug       ~ "Drug",
                     .default   = "Other"
                     ) %>%
           # match factor level order used in paper
           factor(levels = c("Device", "Biological", "Drug", "Other"))
    )
  return(data)
}

preprocess_data.anderson2015.survival <- function(data, censor_date) {
  data <- data %>%
    # Define the event and time variables
    mutate(
      surv.event = if_else(!is.na(results_received_date) & results_received_date <= censor_date, 1, 0),
      surv.time_months = pmin(
        interval(primary_completion_date_imputed, results_received_date) / months(1),
        interval(primary_completion_date_imputed, censor_date) / months(1),
        na.rm = TRUE
      )
    )
  return(data)
}

preprocess_data.anderson2015.regression <- function(data) {
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
        ( interval(primary_completion_date_imputed, results_received_date) < months(12) + days(1) ) |>
        replace_na(FALSE),
      # - 5 years.
      rr.results_reported_5yr =
        ( interval(primary_completion_date_imputed, results_received_date) < years(5) + days(1) ) |>
        replace_na(FALSE),
    ) %>%
    # Phase short names
    mutate(rr.phase =
           fct_recode(phase,
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
           fct_collapse(primary_purpose,
                        Other = setdiff(levels(primary_purpose),
                                        c("Treatment", "Prevention", "Diagnostic"))) |>
           factor(levels = c('Treatment', 'Prevention', 'Diagnostic', 'Other'))
    ) %>%
    mutate(
           # Impute NA with mean
           enrollment.pre = ifelse(is.na(ENROLLMENT), mean(ENROLLMENT, na.rm = TRUE), ENROLLMENT),
           # Replace 0 with a small positive value
           enrollment.pre = ifelse(enrollment.pre == 0, 0.5, enrollment.pre)
    ) |>
    mutate(
           # compare with mntopcom
           rr.study_duration = interval(start_date, primary_completion_date_imputed) / months(1),
           rr.oversight_is_fda = ifelse(oversight == 'United States: Food and Drug Administration',
                                     'Yes', 'No') |>
                             as.factor() |> relevel( ref = 'Yes' ),
           rr.use_of_randomized_assgn = allocation == 'Randomized' & NUMBER_OF_ARMS > 1,
           rr.masking = case_when(
                                  allocation == 'Non-Randomized' ~ "Open",
                                  .default = masking
                          ) |> as.factor() |> relevel( ref = 'Open' ),
           rr.log2_enrollment_less_split = ifelse(enrollment.pre <= split.enrollment, log2(enrollment.pre), 0),
           rr.log2_enrollment_more_split = ifelse(enrollment.pre > split.enrollment, log2(enrollment.pre), 0),
           rr.pc_year_increase_pre_split = ifelse(pc_year_imputed < split.pc_year, pc_year_imputed - split.pc_year, 0),
           rr.pc_year_increase_post_split = ifelse(pc_year_imputed >= split.pc_year, pc_year_imputed - split.pc_year, 0),
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
        NUMBER_OF_ARMS == 1 ~ "one",
        NUMBER_OF_ARMS == 2 ~ "two",
        NUMBER_OF_ARMS >= 3 ~ "three or more"
      ) |> as.factor() |> relevel( ref = "one" )
    ) %>%
    mutate(
      rr.intervention_type  = relevel(intervention_type,  ref = "Drug"      ),
      rr.funding            = relevel(funding,            ref = "NIH"       ),
      rr.phase              = relevel(rr.phase,           ref = "4"         ),
      rr.primary_purpose    = relevel(rr.primary_purpose, ref = "Treatment" ),
      rr.overall_statusc    = relevel(overall_statusc,    ref = "Completed" )
    )

  assert_that( data |> subset( results12 != rr.results_reported_12mo ) |> nrow() == 0,
              msg = 'Original results12 should match computed rr.results_reported_12mo' )

  return(data)
}

preprocess_data <- function(data, censor_date) {
  data <- data %>%
    preprocess_data.anderson2015.type() %>%
    preprocess_data.anderson2015.dates() %>%
    preprocess_data.anderson2015.norm() %>%
    preprocess_data.anderson2015.survival(censor_date) %>%
    preprocess_data.anderson2015.regression()

  return(data)
}

# Function to fit the Kaplan-Meier models
create_survfit_models <- function(data) {
  list(
    fit.funding       = survfit2(Surv(surv.time_months, surv.event) ~ funding,
                                 data = data, start.time = 0),
    fit.phase         = survfit2(Surv(surv.time_months, surv.event) ~ phase.norm,
                                 data = data, start.time = 0),
    fit.interventions = survfit2(Surv(surv.time_months, surv.event) ~ intervention_type,
                                 data = data, start.time = 0),
    fit.status        = survfit2(Surv(surv.time_months, surv.event) ~ overall_statusc,
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
               + rr.overall_statusc
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
  model <- coxph(Surv(time_months, event) ~ intervention_type + phase.norm + funding + overall_statusc, data = data)
  tidy(model, exponentiate = TRUE, conf.int = TRUE)
}
