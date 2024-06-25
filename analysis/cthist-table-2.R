# reproduction of Table 2 in the paper

# issue here:
# https://github.com/insilica/clinicaltrials-compliance-study/issues/14

library(ggplot2)
library(gtsummary)
library(arrow)
library(dplyr)
library(tidyverse)

hlacts <- arrow::read_parquet("brick/analysis-20130927/ctgov-studies-hlact.parquet")

# count each of the funding sources table 2 groups the HLACTs according to the
# three major categories: NIH, Industry, and Other
count_of_sources <- hlacts |>
  dplyr::group_by(funding_source) |>
  dplyr::summarize(n = n())

trials_with_results <- hlacts |>
  filter(!is.na(has_results)) |>
  dplyr::mutate(results12 = ymd(results_rec_date) <=
    ymd(primary_completion_date) + months(12)) |>
  dplyr::filter(funding_source %in% c("NIH", "INDUSTRY", "OTHER")) |>
  gtsummary::tbl_summary(
    by = funding_source,
    label = list(
      has_results ~
        "Results reported by September 2013",
      results12 ~ "Results reported by 12 months after primary completion date",
      months_to_report_results ~ "Median months to report results"
    ),
    statistic = list(
      all_categorical() ~ "{n} / {N} ({p}%)"
    ),
    include = c(
      "funding_source", "has_results", "results12",
      "months_to_report_results"
    ),
    missing = "no"
  ) |>
  add_overall() |>
  modify_header(label = "**Variable**")


trials_w_extension <- hlacts |>
  filter(!is.na(has_results)) |>
  mutate(cdisp_date = (coalesce(
    disp_date, disp_submit_date,
    disp_qc_date
  )) < ymd("2013-09-01")) |>
  filter(!is.na(cdisp_date), funding_source %in% c("INDUSTRY", "NIH", "OTHER")) |>
  mutate(results_reported = results_date < '2013-09-01') |>
  tbl_summary(
    by = funding_source, include = c(
      "funding_source", "has_results",
      "cdisp_date", "months_to_report_results", "results_reported"
    ), missing = "no",
    label = list(has_results ~ "Trials with extension request by September 2013",
    months_to_report_results ~ "Median months to report results",
    results_reported ~ "Results reported before September 2013")
  ) |>
  add_overall() |>
  modify_header(label = "**Variable**")

# this is the segment of Table 2 for
# all trials that did not submit an extension request
# like the above datasets, it also groups by
# median months to report date, and the subset of trials
# that reported results by September 2013
trials_no_extension <- hlacts |>
  filter(!is.na(has_results), ) |>
  mutate(cdisp_date = (coalesce(
    disp_date, disp_submit_date,
    disp_qc_date
  )) >= ymd("2013-09-01")) |>
  filter(is.na(cdisp_date), funding_source %in% c("INDUSTRY", "NIH", "OTHER")) |>
  mutate(results_reported = results_date < '2013-09-01') |>
  # filter(results_reported) |>
  tbl_summary(
    by = funding_source, include = c(
      "funding_source", "has_results",
      "cdisp_date", "months_to_report_results", "results_reported"
    ), missing = "no",
    label = list(has_results ~ "Trials without extension request by September 2013",
    months_to_report_results ~ "Median months to report results",
    results_reported ~ "Results reported before September 2013")
  ) |>
  add_overall() |>
  modify_header(label = "**Variable**")


# view the tables
trials_with_results
trials_w_extension
trials_no_extension

# table stacked
tbl_stack(list(trials_with_results, trials_w_extension, trials_no_extension))
