## {{ begin:preprocess_data.common.survival }}
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
## {{ end:preprocess_data.common.survival }}

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
                  risktable_stats = c("n.risk"),
                  theme = theme_risktable_boxed()) +
    scale_ggsurvfit(x_scales = list(breaks = breaks.fig),
                    y_scales = list(limits = c(0, 1))) +
    xlab("Months after primary completion date")
}
