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
preprocess_data <- function(data, censor_date) {
  data <- data %>%
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
    ) %>%
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
    ) %>%
    # Define the event and time variables
    mutate(
      event = if_else(!is.na(results_received_date) & results_received_date <= censor_date, 1, 0),
      time_months = pmin(
        interval(primary_completion_date_imputed, results_received_date) / months(1),
        interval(primary_completion_date_imputed, censor_date) / months(1),
        na.rm = TRUE
      )
    ) %>%
    # Define the variables for reporting by a particular time, either by
    mutate(
      # - 12 months or
      results_reported_12mo =
        ( interval(primary_completion_date_imputed, results_received_date) < months(12) + days(1) ) |>
        replace_na(FALSE),
      # - 5 years.
      results_reported_5yr =
        ( interval(primary_completion_date_imputed, results_received_date) < years(5) + days(1) ) |>
        replace_na(FALSE),
    ) %>%
    # Phase short names
    mutate(phase.rr =
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
    mutate(primary_purpose.rr =
           fct_collapse(primary_purpose,
                        Other = setdiff(levels(primary_purpose),
                                        c("Treatment", "Prevention", "Diagnostic")))
    )

    assert_that( data |> subset( results12 != results_reported_12mo ) |> nrow() == 0,
                msg = 'Original results12 should match computed results_reported_12mo' )

    return(data)
}

# Function to fit the Kaplan-Meier models
create_survfit_models <- function(data) {
  list(
    fit.funding       = survfit2(Surv(time_months, event) ~ funding,
                                 data = data, start.time = 0),
    fit.phase         = survfit2(Surv(time_months, event) ~ phase.norm,
                                 data = data, start.time = 0),
    fit.interventions = survfit2(Surv(time_months, event) ~ intervention_type,
                                 data = data, start.time = 0),
    fit.status        = survfit2(Surv(time_months, event) ~ overall_statusc,
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

relevel_factors <- function(data) {
  data %>%
    mutate(
      intervention_type  = relevel(intervention_type,  ref = "Drug"      ),
      funding            = relevel(funding,            ref = "NIH"       ),
      phase.rr           = relevel(phase.rr,           ref = "4"         ),
      primary_purpose.rr = relevel(primary_purpose.rr, ref = "Treatment" ),
      overall_statusc    = relevel(overall_statusc,    ref = "Completed" )
    )
}

logistic_regression <- function(data) {
  data <- hlact.studies
  data <- relevel_factors(data) |>
      mutate(
             start_date = create_date_month_name(start_year, start_month),
             pc_year_imputed = year(primary_completion_date_imputed),
      ) |>
      mutate(
             # Impute NA with mean
             enrollment.pre = ifelse(is.na(ENROLLMENT), mean(ENROLLMENT, na.rm = TRUE), ENROLLMENT),
             # Replace 0 with a small positive value
             enrollment.pre = ifelse(enrollment.pre == 0, 0.5, enrollment.pre)
      ) |>
      mutate(
             # compare with mntopcom
             study_duration = interval(start_date, primary_completion_date_imputed) / months(1),
             oversight_is_fda = ifelse(oversight == 'United States: Food and Drug Administration',
                                       'Yes', 'No') |>
                               as.factor() |> relevel( ref = 'Yes' ),
             use_of_randomized_assgn = allocation == 'Randomized' & NUMBER_OF_ARMS > 1,
             masking.rr = case_when(
                                    allocation == 'Non-Randomized' ~ "Open",
                                    .default = masking
                            ) |> as.factor() |> relevel( ref = 'Open' ),
             log2_enrollment_less_32 = ifelse(enrollment.pre <= 32, log2(enrollment.pre), 0),
             log2_enrollment_more_32 = ifelse(enrollment.pre > 32 , log2(enrollment.pre), 0),
             pc_year_increase_pre_2010 = ifelse(pc_year_imputed < 2010, pc_year_imputed - 2010, 0),
             pc_year_increase_post_2010 = ifelse(pc_year_imputed >= 2010, pc_year_imputed - 2010, 0),
  ) |>
  mutate(
         study_duration.clamp = ifelse(study_duration > 24, 24, study_duration)
  ) |>
  mutate(
    sdur.per_3_months_increase_pre_12  = ifelse(study_duration.clamp <= 12, study_duration.clamp / 3, 12 / 3),
    sdur.per_3_months_increase_post_12 = ifelse(study_duration.clamp > 12, (study_duration.clamp - 12) / 3, 0)
  ) |>
  mutate(
    number_of_arms.rr = case_when(
      NUMBER_OF_ARMS == 1 ~ "one",
      NUMBER_OF_ARMS == 2 ~ "two",
      NUMBER_OF_ARMS >= 3 ~ "three or more"
    ) |> as.factor() |> relevel( ref = "one" )
  )

  #models <- list(
  #     intervention_type = glm( results_reported_12mo ~ intervention_type,
  #                               #(intervention_type == 'Drug') +
  #                               #(intervention_type == 'Device') +
  #                               #(intervention_type == 'Biological') +
  #                               #(intervention_type == 'Other'),
  #                              eata = data |> mutate(
  #                                                    intervention_type =
  #                                                      intervention_type #|>
  #                                                      #factor(levels = c("Drug", "Device", "Biological", "Other"))
  #                              ),
  #                             family = binomial ),
  #     phase = glm( results_reported_12mo ~ phase.short_names,
  #                              data = data, family = binomial ),
  #     funding = glm( results_reported_12mo ~ funding,
  #                              data = data, family = binomial ),
  #     status = glm( results_reported_12mo ~ overall_statusc,
  #                              data = data, family = binomial )
  #)
  # >

  # > hlact.studies |> subset( is.na( coalesce( p_completion_year, completion_year, verification_year ) ) ) |> nrow()
  # 0
  # > hlact.studies |> subset( is.na( coalesce( p_completion_year, completion_year ) ) ) |> nrow()
  # 307
  # > hlact.studies |> subset( is.na( coalesce( p_completion_year ) ) ) |> nrow()
  # 403

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
  models <- list(
       overall = glm( results_reported_12mo ~
                     (intervention_type
                      + phase.rr
                      + oversight_is_fda
                      + funding
                      + overall_statusc
                      + primary_purpose.rr
                      + log2_enrollment_less_32 + log2_enrollment_more_32
                      + pc_year_increase_pre_2010 + pc_year_increase_post_2010
                      + sdur.per_3_months_increase_pre_12 + sdur.per_3_months_increase_post_12
                      ##+ mntopcom # weird that this has more exact values?
                      + number_of_arms.rr
                      + use_of_randomized_assgn
                      + masking.rr
                        ),
                     data = data, family = binomial )
  )
  #model <- glm(event ~ intervention_type + phase.norm + funding + overall_statusc, data = data, family = binomial)
  lapply(models, \(x) tidy(x, exponentiate = TRUE, conf.int = TRUE) )
}

cox_regression <- function(data) {
  model <- coxph(Surv(time_months, event) ~ intervention_type + phase.norm + funding + overall_statusc, data = data)
  tidy(model, exponentiate = TRUE, conf.int = TRUE)
}
