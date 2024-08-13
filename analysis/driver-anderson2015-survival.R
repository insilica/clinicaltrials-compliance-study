# source('analysis/driver-anderson2015-survival.R')

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load(
  logger,
  fs,
  parsedate,
  purrr,
  this.path,
  here
)

source('analysis/ctgov.R')

debug_mode <- Sys.getenv("DEBUG") == "1"

### INPUT
hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
  tibble()
log_info(str.print(hlact.studies))#DEBUG
start_date <- as.Date('2008-01-01')
stop_date  <- as.Date('2012-09-01')
# Censoring date
censor_date <- as.Date("2013-09-27")

### PREPROCESS
hlact.studies <- standardize.anderson2015(hlact.studies) |>
  preprocess_data.common(start_date  = start_date,
                         stop_date   = stop_date,
                         censor_date = censor_date)

### DEFINE BREAKS
time_months.max <- max(hlact.studies$surv.time_months, na.rm = TRUE)
breaks.risktable.less_than <- seq(0, time_months.max, by = 12) - 1
breaks.risktable.less_than[1] <- 0
breaks.fig <- seq(0, time_months.max, by = 6)

### CREATE MODELS
fits <- create_survfit_models(hlact.studies)

### PLOT RESULTS

if(debug_mode) {
  # Obtain the current git tag and the path to this script
  git_tag <- system("git describe --tags --always", intern = TRUE)
  script_path <- path_rel(this.path(), here::here())
  output_plot_caption <- sprintf("Prepared on %s %s:%s",
                                 format_iso_8601(Sys.time()),
                                 git_tag, script_path)
}

plot_survfit_with_title <- function(fit, title) {
  f <- plot_survfit(fit, breaks.fig, breaks.risktable.less_than) +
    ggtitle(str_wrap(title, 72)) +
    theme(
          legend.text         = element_text(size = rel(1.0),
                                             margin = margin(r = 20, unit = "pt"))
    )

  if(debug_mode) {
    f <- f + labs(caption = output_plot_caption)
  }

  return(f)
}

dir_create('figtab/anderson2015')
ggsave.partial <- partial(ggsave, ... = ,
                          dpi = 300, width = 10 )

# Fig 2
show(fig.surv.funding <- plot_survfit_with_title(fits$fit.funding,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Funding"))
ggsave.partial('figtab/anderson2015/fig_2.survfit.funding.png')

# Fig S1
show(fig.surv.phase <- plot_survfit_with_title(fits$fit.phase,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Phase"))
ggsave.partial('figtab/anderson2015/fig_s1.survfit.phase.png')

# Fig S2
show(fig.surv.interventions <- plot_survfit_with_title(fits$fit.interventions,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Intervention Type"))
ggsave.partial('figtab/anderson2015/fig_s2.survfit.interventions.png')

# Fig S3
show(fig.surv.status <- plot_survfit_with_title(fits$fit.status,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Terminated/Completed Status"))
ggsave.partial('figtab/anderson2015/fig_s3.survfit.status.png')
