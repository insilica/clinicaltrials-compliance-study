# if(!sys.nframe()) { source('analysis/driver-rule-effective-date.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

window.titles <- list(
  'rule-effective-date-before' = 'Before Rule Effective Date',
  'rule-effective-date-after'  = 'After Rule Effective Date'
)

window.names <- list(
  'rule-effective-date-before' = 'Window 1',
  'rule-effective-date-after'  = 'Window 2'
)

strat.var.labels <- list(
  fit.funding       = 'Funding',
  fit.phase         = 'Phase',
  fit.interventions = 'Intervention Type',
  fit.status        = 'Trial Status'#,
)

agg.window.compare.rule_effective <- windows.rdata.read('brick/rule-effective-date_processed')

( agg.window.compare.rule_effective.short.names <-
    agg.window.compare.rule_effective
    |> setNames(window.names[names(agg.window.compare.rule_effective)]) )

plot.windows.stacked.chart(agg.window.compare.rule_effective.short.names,
			   with_names = TRUE,
			   with_facet = "common.funding",
			   window.time.label.oneline = TRUE )

for (interval.col in c("cr.interval_to_results_no_extensions_no_censor", "cr.interval_to_results_with_extensions_no_censor")) {
  plot.windows.stacked.chart(agg.window.compare.rule_effective.short.names,
                             with_names = TRUE,
                             with_facet = NULL,
                             with_interval_column = interval.col,
                             window.time.label.oneline = TRUE,
                             ggsave.opts = list(width = 8, height = 8),
                             fig.cb = \(x) {
                               ( x
                                + ggtitle(paste("Percentage of Studies Reporting Results",
                                                "Window 1 and Window 2", sep = "\n") )
                                + theme(
                                    plot.title = element_text(size = 18, face = "bold")
                                  )
                               )
                             }
                            )
}

survival.fits <- map(agg.window.compare.rule_effective,
    ~ create_survfit_models(.x$hlact.studies))

plot_survifit_wrap <- function(data, fit) {
  #time_months.max <- max(data$hlact.studies$surv.time_months, na.rm = TRUE)
  time_months.max <- 36 # 36 months
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
            legend.position.inside = c(0.20, 0.95),  # Adjust these values as needed
            legend.justification = c("right", "top"),  # This aligns the legend box's corner to the position
            legend.background = element_rect(fill = "white", color = "NA", linewidth = 0.5),  # Optional: make background semi-transparent or solid
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
  for (ext in c("png", "svg", "pdf")) {
    ggsave(paste0(plot.output.base, ".", ext), width = 8, height = 8)
  }
}
}


for(strat.var in names(strat.var.labels)) {
  plots <- list()
  for(window.name in names(survival.fits)) {
    print(window.name)
    print(strat.var)
    # Create and build the plot
    plots[[window.name]] <- ggsurvfit_build(
      plot_survifit_wrap(
        agg.window.compare.rule_effective[[window.name]],
        survival.fits[[window.name]][[strat.var]]
      )
      + ggtitle(window.names[[window.name]])
      + theme(legend.position = 'none')
    )
  }

  # Create an unbuilt version just for legend extraction
  (legend_plot <-
     plot_survifit_wrap(agg.window.compare.rule_effective[['rule-effective-date-after']],
                        survival.fits[['rule-effective-date-after']][[strat.var]])
     + theme(legend.direction = "vertical",
             legend.position = "right")
  )
  # Extract the legend
  shared_legend <- get_legend(legend_plot)

  combined_plot <- ggarrange(
    plots[['rule-effective-date-before']],
    plots[['rule-effective-date-after']],
    ncol = 2,
    #common.legend = TRUE,
    legend = "right",
    legend.grob = shared_legend
  ) + theme(plot.margin = margin(t = 5, r = 25, b = 5, l = 5, unit = "pt"))

  # Add the overall title
  combined_plot <- annotate_figure(combined_plot,
    top = text_grob(glue("Cumulative % of Trials Reporting to ClinicalTrials.gov Stratified by {strat.var.labels[[strat.var]]}"),
                    size = 14)
  )

  print(combined_plot)

  # Save combined plot
  plot.output.base <- fs::path(glue(
    "figtab/{agg.window.compare.rule_effective[[1]]$window$prefix}/fig.combined.surv.strat-{strat.var}"))
  fs::dir_create(path_dir(plot.output.base))
  for (ext in c("png", "svg", "pdf")) {
    ggsave(paste0(plot.output.base, ".", ext),
           plot = combined_plot,
           width = 12, height = 8)
  }
}

survival.logranks <- (
  agg.window.compare.rule_effective
    %>% set_names(str_remove(names(.), "rule-effective-date-"))
    %>% create_logranks.all()
)

survival.logranks$overall |> map( ~ .x$pvalue )

survival.logranks$strata |> map( ~ .x$pvalue )

survival.logranks$pairwise

# Extract and adjust p-values
pvalues <- survival.logranks$pairwise |>
  map(~map_dbl(.x, ~.x$pvalue)) |>
  unlist()
print(tidy(pvalues))
adjusted_pvalues <- p.adjust(pvalues, method = "hochberg")
print( tidy(adjusted_pvalues) )

pvalue_df <- survival.logranks$pairwise |>
  map(\(group_tests)
    imap(group_tests, \(stratum_test, idx) tibble(
      stratum = idx,
      pvalue  = stratum_test$pvalue
    )) |> list_rbind()
  ) |>
  list_rbind(names_to = "group") |>
  mutate(group = str_to_title(str_remove(group, "logrank\\."))) |>
  group_by(group) |>
  mutate(p.adjusted = p.adjust(pvalue, method = "hochberg")) |>
  ungroup()
print(pvalue_df)

pvalue_df |>
	  knitr::kable(
	    format = "latex",
	    digits = 2,
	    scientific = TRUE,
	    col.names = c("Group", "Stratum", "P-value", "Adjusted P-value")
	  ) |>
	  kableExtra::row_spec(c(3, 7, 11), extra_css = "border-bottom: 1px solid")


pvalue_df |>
  mutate(
    pvalue = formatC(pvalue, format = "e", digits = 2),
    p.adjusted = formatC(p.adjusted, format = "e", digits = 2)
  ) |>
  group_by(group) |>
  mutate(group = if_else(row_number() == 1, group, "")) |>
  ungroup() |>
  knitr::kable(
    format = "latex",
    booktabs = TRUE,
    col.names = c("Group", "Stratum", "P-value", "Adjusted P-value")
  ) |>
  kableExtra::pack_rows(index = table(pvalue_df$group))


####

create_prop_tests <- function(agg.windows, var_name) {
  agg.windows |>
    bind_rows(.id = "period") |>
    mutate(period = factor(period, levels = c("rule-effective-date-before", "rule-effective-date-after"))) |>
    group_by(!!rlang::sym(var_name)) |>
    summarise(
      table = list(table(!rr.results_reported_12mo, period))
    ) |>
    tibble::deframe() |>
    map(~prop.test(.x, alternative = 'less'))
}

# Create all tests
h <- map(agg.window.compare.rule_effective, ~ .x$hlact.studies )
chisq.tests <- list(
    funding       = h |> create_prop_tests("common.funding"),
    phase         = h |> create_prop_tests("common.phase.norm"),
    interventions = h |> create_prop_tests("common.intervention_type"),
    status        = h |> create_prop_tests("common.overall_status")
)
print(chisq.tests)

# Create prop tests with correction table
chisq_df <- chisq.tests |>
  imap_dfr(\(group_tests, group_name) {
    imap_dfr(group_tests, \(test, stratum_name) {
      tibble(
        group = group_name,
        stratum = stratum_name,
        pvalue = test$p.value
      )
    })
  }) |>
  group_by(group) |>
  mutate(p.adjusted = p.adjust(pvalue, method = "hochberg")) |>
  ungroup()
print(chisq_df)

# Create table like logrank
chisq_table <- chisq_df |>
  mutate(
    pvalue = formatC(pvalue, format = "e", digits = 2),
    p.adjusted = formatC(p.adjusted, format = "e", digits = 2),
    group = str_to_title(group)
  ) |>
  group_by(group) |>
  mutate(group = if_else(row_number() == 1, group, "")) |>
  ungroup() |>
  knitr::kable(
    format = "latex",
    booktabs = TRUE,
    col.names = c("Group", "Stratum", "P-value", "Adjusted P-value")
  ) |>
  kableExtra::pack_rows(index = table(chisq_df$group))
