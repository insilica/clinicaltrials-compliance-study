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

create_logranks.all_data <- function(agg.window) {
  combined_data <- agg.window |>
    imap(~mutate(.x$hlact.studies, window_name = .y)) |>
    bind_rows()
  survdiff(Surv(surv.time_months, surv.event) ~ window_name,
           data = combined_data)
}

# Functions to perform Log-Rank Test
create_logranks.overall <- function(agg.window) {
  combined_data <- agg.window |>
    imap(~mutate(.x$hlact.studies, window_name = .y)) |>
    bind_rows()
  list(
    logrank.funding       = survdiff(Surv(surv.time_months, surv.event) ~ window_name + (common.funding),
                                data = combined_data),
    logrank.phase         = survdiff(Surv(surv.time_months, surv.event) ~ window_name + (common.phase.norm),
                                    data = combined_data),
    logrank.intervention  = survdiff(Surv(surv.time_months, surv.event) ~ window_name + (common.intervention_type),
                                    data = combined_data),
    logrank.purpose       = survdiff(Surv(surv.time_months, surv.event) ~ window_name + (rr.primary_purpose),
                                    data = combined_data |> filter( !is.na(rr.primary_purpose) )),
    logrank.status        = survdiff(Surv(surv.time_months, surv.event) ~ window_name + (common.overall_status),
                                    data = combined_data)
  )
}

create_logranks.strata <- function(agg.window) {
  combined_data <- agg.window |>
    imap(~mutate(.x$hlact.studies, window_name = .y)) |>
    bind_rows()
  list(
    logrank.funding       = survdiff(Surv(surv.time_months, surv.event) ~ window_name + strata(common.funding),
                                data = combined_data),
    logrank.phase         = survdiff(Surv(surv.time_months, surv.event) ~ window_name + strata(common.phase.norm),
                                    data = combined_data),
    logrank.intervention  = survdiff(Surv(surv.time_months, surv.event) ~ window_name + strata(common.intervention_type),
                                    data = combined_data),
    logrank.purpose       = survdiff(Surv(surv.time_months, surv.event) ~ window_name + strata(rr.primary_purpose),
                                    data = combined_data |> filter( !is.na(rr.primary_purpose) )),
    logrank.status        = survdiff(Surv(surv.time_months, surv.event) ~ window_name + strata(common.overall_status),
                                    data = combined_data)
  )
}

create_logranks.pairwise <- function(agg.window) {
  combined_data <- agg.window |>
    imap(~mutate(.x$hlact.studies, window_name = .y)) |>
    bind_rows()

  list(
    logrank.funding = combined_data |>
      group_by(common.funding) |>
      group_map(~setNames(list(survdiff(Surv(surv.time_months, surv.event) ~ window_name, data = .x)),
                          pull(.y))) |> unlist(recursive = FALSE),
    logrank.phase = combined_data |>
      group_by(common.phase.norm) |>
      group_map(~setNames(list(survdiff(Surv(surv.time_months, surv.event) ~ window_name, data = .x)),
                          pull(.y))) |> unlist(recursive = FALSE),

    logrank.intervention = combined_data |>
      group_by(common.intervention_type) |>
      group_map(~setNames(list(survdiff(Surv(surv.time_months, surv.event) ~ window_name, data = .x)),
                          pull(.y))) |> unlist(recursive = FALSE),

    logrank.purpose = combined_data |>
      filter( !is.na(rr.primary_purpose) ) |>
      group_by(rr.primary_purpose) |>
      group_map(~setNames(list(survdiff(Surv(surv.time_months, surv.event) ~ window_name, data = .x)),
                          pull(.y))) |> unlist(recursive = FALSE),

    logrank.status = combined_data |>
      group_by(common.overall_status) |>
      group_map(~setNames(list(survdiff(Surv(surv.time_months, surv.event) ~ window_name, data = .x)),
                          pull(.y))) |> unlist(recursive = FALSE)
  )
}

create_logranks.all <- function(agg.window) {
  list(
    overall  = create_logranks.overall(agg.window),
    strata   = create_logranks.strata(agg.window),
    pairwise = create_logranks.pairwise(agg.window)
  )
}
