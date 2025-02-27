# if(!sys.nframe()) { source('analysis/driver-results-compliance-by-sponsor.R') }
if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger, readr )

source('analysis/ctgov.R')

params <- window.params.read()

output.path.base <- 'figtab/post-rule-to-20240430-by_sponsor'
fs::dir_create(output.path.base)

agg.window.postrule <- windows.rdata.read('brick/post-rule-to-20240430_processed')

agg.window.postrule[[1]]$hlact.studies |>
  mutate(
    # Which type of intervalue to use for the `dateproc.results_reported.within_inc()`
    # computation below:
    cr.interval_to_results_default = cr.interval_to_results_with_extensions_no_censor,
    # - 12 months or
    cr.results_reported_12mo_with_extensions =
      dateproc.results_reported.within_inc(pick(everything()), months(12)),
  ) |>
  group_by(schema1.lead_sponsor_funding_source, schema1.lead_sponsor_name) |>
  summarize(
    total_trials = n(),
    reporting_rate_with_extensions = mean(cr.results_reported_12mo_with_extensions),
    reporting_rate_no_extensions   = mean(cr.results_reported_12mo),
    compliant_ncts = list(schema1.nct_id[cr.results_reported_12mo_with_extensions == TRUE]),
    noncompliant_ncts = list(schema1.nct_id[cr.results_reported_12mo_with_extensions == FALSE])
  ) |>
  mutate(
    compliant_ncts = sapply(compliant_ncts, paste, collapse = "|"),
    noncompliant_ncts = sapply(noncompliant_ncts, paste, collapse = "|")
  ) |>
  arrange(-total_trials) |>
  write_csv(fs::path(output.path.base, "sponsor_compliance_summary.csv"))

#windows.rdata.write('brick/rule-effective-date_processed', agg.window.compare.rule_effective)
#windows.hlact.write('brick/rule-effective-date_processed', agg.window.compare.rule_effective)
