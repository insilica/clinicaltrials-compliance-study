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

### INPUT & PREPROCESS
hlact.studies <- anderson2015.read_and_process()

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
  f <- ( plot_survfit(fit, breaks.fig, breaks.risktable.less_than) +
    ggtitle(str_wrap(title, 72))
    #theme(
    #      legend.text         = element_text(size = rel(1.0),
    #                                         margin = margin(r = 20, unit = "pt"))
    #)
          +
          # Position the legend inside the plot
          theme(
            legend.position = c(0.20, 0.95),  # Adjust these values as needed
            legend.justification = c("right", "top"),  # This aligns the legend box's corner to the position
            legend.background = element_rect(fill = "white", color = "NA", size = 0.5),  # Optional: make background semi-transparent or solid
            legend.key = element_rect(fill = "white", colour = "white")  # Adjust key background
          )
  )

  if(debug_mode) {
    f <- f + labs(caption = output_plot_caption)
  }

  return(f)
}

dir_create('figtab/anderson2015')
ggsave.partial <- partial(ggsave, ... = ,
                          dpi = 300, width = 8, height = 8 )

# Fig 2
show(fig.surv.funding <- plot_survfit_with_title(fits$fit.funding,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Funding"))
for (ext in c("png", "svg")) {
  ggsave.partial(paste0('figtab/anderson2015/fig_2.survfit.funding', ".", ext))
}

# Fig S1
show(fig.surv.phase <- plot_survfit_with_title(fits$fit.phase,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Phase"))
for (ext in c("png", "svg")) {
  ggsave.partial(paste0('figtab/anderson2015/fig_s1.survfit.phase', ".", ext))
}

# Fig S2
show(fig.surv.interventions <- plot_survfit_with_title(fits$fit.interventions,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Intervention Type"))
for (ext in c("png", "svg")) {
  ggsave.partial(paste0('figtab/anderson2015/fig_s2.survfit.interventions', ".", ext))
}

# Fig S3
show(fig.surv.status <- plot_survfit_with_title(fits$fit.status,
     "Trials Reporting Results versus Months from Primary Completion Date Stratified by Terminated/Completed Status"))
for (ext in c("png", "svg")) {
  ggsave.partial(paste0('figtab/anderson2015/fig_s3.survfit.status', ".", ext))
}
