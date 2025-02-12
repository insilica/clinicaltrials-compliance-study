# if(!sys.nframe()) { source('analysis/driver-rule-effective-date-extra-analysis.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

fs::dir_create("figtab/rule-effective-extra-analysis")

agg.window.compare.rule_effective <- windows.rdata.read('brick/rule-effective-date_processed')

analysis.groups <- c("Funding", "Phase", "Intervention", "Purpose")

### Log-rank test ###

survival.logranks <- (
  agg.window.compare.rule_effective
    %>% set_names(str_remove(names(.), "rule-effective-date-"))
    %>% create_logranks.all()
)

## H0: The survival curves are the same across all groups
## H1: At least one curve differs from the others
print("Overall test p-values (testing if any curves differ):")
survival.logranks$overall |> map( ~ .x$pvalue )

## H0: The survival curves are the same after controlling for strata
## (But this isn't that meaningful as the strata are not confounders)
print("Stratified test p-values (controlling for each factor):")
survival.logranks$strata |> map( ~ .x$pvalue )


## H0: Within each stratum, the before/after survival curves are the same
## This is our primary analysis of interest
print("Pairwise comparisons within each stratum:")
survival.logranks$pairwise

# Extract and adjust p-values
lr.pvalues <- survival.logranks$pairwise |>
  map(~map_dbl(.x, ~.x$pvalue)) |>
  unlist()
print(tidy(lr.pvalues))
lr.adjusted_pvalues <- p.adjust(lr.pvalues, method = "hochberg")
print( tidy(lr.adjusted_pvalues) )

lr.pvalue_df <- survival.logranks$pairwise |>
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
print(lr.pvalue_df)

local({
lr.pvalue_df <- lr.pvalue_df |>
  filter( group != 'Status' )
lr.pvalue_df |>
  mutate(
    pvalue = formatC(pvalue, format = "e", digits = 2),
    p.adjusted = paste0(
      formatC(p.adjusted, format = "e", digits = 2),
      symnum(p.adjusted, cutpoints = c(0, 0.001, 1), symbols = c("*", ""))
    )
  ) |>
  group_by(group) |>
  #mutate(group = if_else(row_number() == 1, group, "")) |>
  ungroup() |>
  mutate(group = "") |>
  knitr::kable(
    format = "latex",
    booktabs = TRUE,
    col.names = c("Group", "Stratum", "P-value", "Adjusted P-value")
  ) |>
  kableExtra::pack_rows(index = table(factor(lr.pvalue_df$group, levels = analysis.groups))) |>
  paste0("\n") |>
  cat(file = "figtab/rule-effective-extra-analysis/log-rank-pval.tab.tex")
})


####

### Chi-squared proportions test ###

create_prop_tests <- function(agg.windows, var_name = NULL) {
  agg.windows |>
    bind_rows(.id = "period") |>
    mutate(period = factor(period, levels = c("rule-effective-date-before", "rule-effective-date-after"))) |>
    (if (is.null(var_name)) identity else \(x) group_by(x, !!rlang::sym(var_name)))() |>
    summarise(
      table = list(table(period, !rr.results_reported_12mo))
    ) |>
    tibble::deframe() |>
    map(~prop.test(.x, alternative = 'less'))
}

chisq.tests.all <- local({
  h <- map(agg.window.compare.rule_effective, ~ .x$hlact.studies )
  h |> create_prop_tests()
});
cat(paste0(
     "Chi-squared over all data\n",
     chisq.tests.all |> str.print()
))

# Create all tests
chisq.tests <- local({
  h <- map(agg.window.compare.rule_effective, ~ .x$hlact.studies )
  list(
      funding       = h |> create_prop_tests("common.funding"),
      phase         = h |> create_prop_tests("common.phase.norm"),
      intervention  = h |> create_prop_tests("common.intervention_type"),
      purpose       = h |>
        map( ~ filter(.x, !is.na(rr.primary_purpose) ) ) |>
        create_prop_tests("rr.primary_purpose"),
      status        = h |> create_prop_tests("common.overall_status")
  )
})
print(chisq.tests)

# Create prop tests with correction table
chisq.pvalue_df <- chisq.tests |>
  imap_dfr(\(group_tests, group_name) {
    imap_dfr(group_tests, \(test, stratum_name) {
      tibble(
        group = str_to_title(group_name),
        stratum = stratum_name,
        pvalue = test$p.value
      )
    })
  }) |>
  group_by(group) |>
  mutate(p.adjusted = p.adjust(pvalue, method = "hochberg")) |>
  ungroup()
print(chisq.pvalue_df)

# Create table like logrank
local({
chisq.pvalue_df <- chisq.pvalue_df |>
  filter( group != 'Status' )
chisq.pvalue_df |>
  mutate(
    pvalue = formatC(pvalue, format = "e", digits = 2),
    p.adjusted = paste0(
      formatC(p.adjusted, format = "e", digits = 2),
      symnum(p.adjusted, cutpoints = c(0, 0.001, 1), symbols = c("*", ""))
    )
  ) |>
  group_by(group) |>
  #mutate(group = if_else(row_number() == 1, group, "")) |>
  ungroup() |>
  mutate(group = "") |>
  knitr::kable(
    format = "latex",
    booktabs = TRUE,
    col.names = c("Group", "Stratum", "P-value", "Adjusted P-value")
  ) |>
  kableExtra::pack_rows(index = table(factor(chisq.pvalue_df$group, levels = analysis.groups))) |>
  paste0("\n") |>
  cat(file = "figtab/rule-effective-extra-analysis/chisq-pval.table.tex")
})
