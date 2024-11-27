# if(!sys.nframe()) { source('analysis/driver-rule-effective-date.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

window.titles <- list(
  'rule-effective-date-before' = 'Before Rule Effective Date',
  'rule-effective-date-after'  = 'After Rule Effective Date'
)

strat.var.labels <- list(
  fit.funding       = 'Funding',
  fit.phase         = 'Phase',
  fit.interventions = 'Intervention Type',
  fit.status        = 'Trial Status'#,
)

agg.window.compare.rule_effective <- windows.rdata.read('brick/rule-effective-date_processed')

plot.windows.stacked.chart(agg.window.compare.rule_effective, with_names = TRUE)
plot.windows.stacked.chart(agg.window.compare.rule_effective, with_names = TRUE, with_facet = NULL)

survival.fits <- map(agg.window.compare.rule_effective,
    ~ create_survfit_models(.x$hlact.studies))

plot_survifit_wrap <- function(data, fit) {
  time_months.max <- max(data$hlact.studies$surv.time_months, na.rm = TRUE)
  breaks.risktable.less_than <- seq(0, time_months.max, by = 12) - 1
  breaks.risktable.less_than[1] <- 0
  breaks.fig <- seq(0, time_months.max, by = 6)
  f <- plot_survfit(fit, breaks.fig, breaks.risktable.less_than)
  return(f)
}

for(strat.var in names(strat.var.labels)) {
for(window.name in names(survival.fits)) {
  print(window.name)
  #strat.var <- 'fit.funding'
  print(strat.var)
  fig <- (
          plot_survifit_wrap(
           agg.window.compare.rule_effective[[window.name]],
           survival.fits[[window.name]][[strat.var]]
          )
          + ggtitle(str_wrap(glue(
              "Trials Reporting Results versus Months from Primary Completion Date",
              " {window.titles[[window.name]]}",
              " Stratified by {strat.var.labels[[strat.var]]}",
            ),72))
          +
          # Position the legend inside the plot
          theme(
            legend.position = c(0.20, 0.95),  # Adjust these values as needed
            legend.justification = c("right", "top"),  # This aligns the legend box's corner to the position
            legend.background = element_rect(fill = "white", color = "NA", size = 0.5),  # Optional: make background semi-transparent or solid
            legend.key = element_rect(fill = "white", colour = "white")  # Adjust key background
          )
          #+ theme(
          #  legend.position = 'right',
          #  legend.direction = 'vertical'
          #)
  )
  show(fig)
  plot.output.base <- fs::path(glue(
      "figtab/{agg.window.compare.rule_effective[[1]]$window$prefix}/fig.window-{window.name}.surv.strat-{strat.var}"))
  fs::dir_create(path_dir(plot.output.base))
  for (ext in c("png", "svg")) {
    ggsave(paste0(plot.output.base, ".", ext), width = 8, height = 8)
  }
}
}
