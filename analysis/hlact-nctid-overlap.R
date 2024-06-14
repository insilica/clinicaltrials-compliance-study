# DESCRIPTION
#
# 1. Retrieves the NCT IDs from the CTGOV "HLACTs" and from the original paper
#    data.
# 2. Compare their intersection using UpSet diagram.
library(arrow)
library(dotenv)
library(dplyr)
library(readr)
library(vroom)

library(ggplot2)
library(ComplexUpset)

dotenv::load_dot_env(".env")

## Data from ctgov JSON

query_df <- arrow::read_parquet("brick/analysis-20130927/ctgov-studies-hlact.parquet")

## Data from paper results

paper_df <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet')

## Encode data for UpSet

all_ids <- unique(c(query_df$nct_id, paper_df$NCT_ID))
upset_df <- data.frame(
	ID           = all_ids,
	ctgov_hlact   = all_ids %in% query_df$nct_id,
	anderson2015 = all_ids %in% paper_df$NCT_ID
)

## Plot the UpSet diagram

plot( upset( upset_df, c('ctgov_hlact', 'anderson2015'), name = 'ID source' ) )
ggsave('nctid-overlap-all.png', width = 12, height = 8)

all_ids <- unique(c(query_df$nct_id, paper_df$NCT_ID))
upset_df <- data.frame(
	ctgov_hlact   = all_ids %in% query_df$nct_id,
	anderson2015 = all_ids %in% paper_df$NCT_ID
)
plot( upset( upset_df, c('ctgov_hlact', 'anderson2015'), name = 'ID source' ) )
ggsave('hlact-overlap-historical.png', width = 12, height = 8)
