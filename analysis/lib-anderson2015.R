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
  stringr
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
  data %>%
    rename(nct_id = NCT_ID) %>%
    mutate(
      # These are all factor variables.
      across(c(phase, overall_statusc, funding, primary_purpose, RESPONSIBLE_PARTY_TYPE), as.factor),
      # Interventions are stored as { "Yes",  "No" }
      across(c(behavioral, biological, device, dietsup, drug, genetic, procedure, radiation, otherint), \(x) x == 'Yes'),
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
    )
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
