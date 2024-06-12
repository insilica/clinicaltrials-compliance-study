# vim: fdm=marker

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


### INPUT {{{
hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
  rename(nct_id = NCT_ID) |>
  mutate(
    across(c(phase, overall_statusc, funding, primary_purpose, RESPONSIBLE_PARTY_TYPE), as.factor),
    # Interventions are stored as { "Yes",  "No" }
    across(c(behavioral, biological, device, dietsup, drug, genetic, procedure, radiation, otherint), \(x) x == 'Yes'),
  ) |>
  tibble()
print(hlact.studies)#DEBUG
# Censoring date
censor_date <- as.Date("2013-09-27")
# }}}

### PREPROCESS{{{

# Function to create date from year and month
create_date_w_mfmt <- function(year, month, month_fmt) {
  date_fmt <- paste("%Y", month_fmt, "%d", sep = "-")
  if_else(!is.na(year) & !is.na(month),
      as.Date( paste(year, month, "01", sep = "-") , format = date_fmt),
      NA)
}
create_date_month_name <- function(year, month) { create_date_w_mfmt(year, month, "%B") }
create_date_month_int  <- function(year, month) { create_date_w_mfmt(year, month, "%m") }

# Create the primary completion date based on the given priority
hlact.studies <- hlact.studies %>%
  mutate(primary_completion_date_imputed = coalesce(
    create_date_month_name(p_completion_year, p_completion_month),
    create_date_month_name(  completion_year,   completion_month),
    create_date_month_name(verification_year, verification_month)
  ))


# Convert results_received_date to Date object
hlact.studies <- hlact.studies %>%
  mutate(results_received_date = create_date_month_int(resultsreceived_year, resultsreceived_month))

# Normalize phases
hlact.studies <- hlact.studies %>%
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
  )

# }}}


# Define the event and time variables
hlact.studies <- hlact.studies %>%
  mutate(
    event = if_else(!is.na(results_received_date) & results_received_date <= censor_date, 1, 0),
    time_months = pmin(
      interval(primary_completion_date_imputed, results_received_date) / months(1),
      interval(primary_completion_date_imputed, censor_date) / months(1),
      na.rm = TRUE
    )
  )



# Fit the Kaplan-Meier model
fit.funding <- survfit2(Surv(time_months, event) ~ funding,
                       data = hlact.studies, start.time = 0)
fit.phase <- survfit2(Surv(time_months, event) ~ phase.norm,
                     data = hlact.studies, start.time = 0)
fit.interventions <- survfit2(Surv(time_months, event) ~
   behavioral +
   biological +
   device     +
   dietsup    +
   drug       +
   genetic    +
   procedure  +
   radiation  +
   otherint   ,
 data = hlact.studies, start.time = 0)
fit.status <- survfit2(Surv(time_months, event) ~ overall_statusc,
                       data = hlact.studies, start.time = 0)

time_months.max <- max(hlact.studies$time_months, na.rm = TRUE)
breaks.risktable.less_than <- seq(0, time_months.max, by = 12) - 1
breaks.risktable.less_than[1] <- 0
breaks.fig <- seq(0, time_months.max, by = 6)

# Plot the results
#fig.surv.funding <-
#  ggsurvplot(fit.funding, data = hlact.studies, risk.table = FALSE,
#             #ggtheme = theme_minimal(),
#             #palette = "Dark2",
#             break.time.by = 6,
#             risk.table.breaks = seq(0, max(hlact.studies$time_months, na.rm = TRUE), by = 12),
#             title = "Kaplan-Meier Estimates of Clinical Trials Results Reporting",
#             xlab = "Time (Months)",
#             ylab = "Cumulative Percentage of Trials Reporting Results") +

##fig.rt.funding <-  ggrisktable(fit.funding, data = hlact.studies,
##             break.time.by = 11)
#show(fig.surv.funding)
#show(fig.rt.funding)

plot_survfit <- function(fit) {
  fig <- fit |>
    ggsurvfit() +
    add_risktable( times = breaks.risktable.less_than,
                  risktable_stats = c("n.risk") ) +
    scale_ggsurvfit(x_scales = list(breaks = breaks.fig )) +
    xlab("Months after primary completion date")
  return(fig)
}

# Fig 2
show( fig.surv.funding <- plot_survfit(fit.funding) +
     ggtitle(
             "Trials Reporting Results versus Months from Primary Completion Date Stratified by Funding"
             ))

# Fig S1
show( fig.surv.phase <- plot_survfit(fit.phase) +
     ggtitle(
             "Trials Reporting Results versus Months from Primary Completion Date Stratified by Phase"
             ))

# Fig S2 (TODO, merge interventions)
show( fig.surv.interventions <- plot_survfit(fit.interventions) +
     ggtitle(str_wrap(
             "Trials Reporting Results versus Months from Primary Completion Date Stratified by Intervention Type",
             72)))

# Fig S3
show( fig.surv.status <- plot_survfit(fit.status) +
     ggtitle(str_wrap(
             "Trials Reporting Results versus Months from Primary Completion Date Stratified by Terminated/Completed Status",
             72)))


# Save the plot
ggsave("kaplan_meier_plot.png")
