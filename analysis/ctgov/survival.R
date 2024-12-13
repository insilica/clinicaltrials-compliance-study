## {{ begin:preprocess_data.common.survival }}
preprocess_data.common.survival <- function(data, censor_date) {
  data <- data %>%
    # Define the event and time variables
    mutate(
      surv.event = if_else(!is.na(common.results_received_date) & common.results_received_date <= censor_date, 1, 0),
      surv.time_months = pmin(
        cr.interval_to_results_no_extensions_no_censor / months(1),
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
    ggsurvfit(type = 'risk', 
              size=1.5
    ) +
    add_risktable(
      times = breaks.risktable.less_than,
      #times = c(0, 12, 24, 36, 48, 60)
      #risktable_stats = c("n.risk"),
      risktable_stats = c("{paste0(' ', n.risk)}"),
      stats_label = c('N trials that have not reported results'),
      #theme = theme_risktable_boxed(),
      # theme = theme_risktable_plain(),
      risktable_height = 0.20,
      size = 2.5, # font size
    ) +
    # theme_risktable(base_size = 14) +
    scale_ggsurvfit(
      #x_scales = list(breaks = breaks.fig, limits=c(0, 60)),
      x_scales = list(breaks = breaks.fig, limits=c(0, max(breaks.fig))),
      y_scales = list(limits = c(0, 1))
    ) +
    scale_color_brewer(palette = "Dark2") + 
    theme(
      #text = element_text(family = "Tahoma"),
      axis.title.x = element_text(size = 16),  # X-axis title font size
      axis.title.y = element_text(size = 16),  # Y-axis title font size
      axis.text.x = element_text(size = 14),   # X-axis text size
      axis.text.y = element_text(size = 14),    # Y-axis text size
      panel.border = element_blank(),
      axis.line = element_line(size = 0.5),
      panel.background = element_blank(),
      panel.grid.minor = element_line(color = "#eaeaea"),
      panel.grid.major = element_line(color = "#eaeaea"),
      
    ) + 
    xlab("Months after primary completion date") + 
    ylab("Trials (%)") 
}
