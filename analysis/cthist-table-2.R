# reproduction of Table 2 in the paper

# issue here:
# https://github.com/insilica/clinicaltrials-compliance-study/issues/14

library(arrow)
library(dplyr)

hlacts <- arrow::read_parquet("brick/analysis-20130927/ctgov-studies-hlact.parquet")

# count each of the funding sources table 2 groups the HLACTs according to the
# three major categories: NIH, Industry, and Other
count_of_sources <- hlacts |>
    dplyr::group_by(funding_source) |>
    dplyr::summarize(n = n())

trials_with_results <- hlacts |>
    dplyr::filter(!is.na(has_results), results_date < "2013-09-27") |>
    dplyr::group_by(funding_source) |>
    dplyr::count(has_results, sort = TRUE, name = "count") |>
    dplyr::ungroup() |>
    dplyr::mutate(percentage = count/sum(count) * 100) |>
    dplyr::select(funding_source, count, percentage)


