# DESCRIPTION
#
# 1. Retrieves the NCT IDs from the given SQL query and from the original paper
#    data.
# 2. Compare their intersection using UpSet diagram.
library(arrow)
library(DBI)
library(RPostgres)
library(dotenv)
library(dplyr)
library(readr)
library(vroom)

library(ggplot2)
library(ComplexUpset)

dotenv::load_dot_env(".env")

## Data from database

query_file <- 'sql/aact2024_init.sql'

conn <- dbConnect(RPostgres::Postgres(),
  dbname = "aact_20240430",
  host = Sys.getenv("PGHOST"),
  port = Sys.getenv("PGPORT"))

res <- dbSendQuery(conn, read_file(query_file))
query_df <- dbFetch(res)
dbClearResult(res)

## Data from relevant

relevant_df <- vroom('relevant-studies.csv')

## Data from paper results

paper_df <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet')

## Encode data for UpSet

all_ids <- unique(c(query_df$nct_id, relevant_df$nctid, paper_df$NCT_ID))
upset_df <- data.frame(
	ID           = all_ids,
	stanford_db20240430   = all_ids %in% query_df$nct_id,
	stanford_historical   = all_ids %in% relevant_df$nctid,
	anderson2015 = all_ids %in% paper_df$NCT_ID
)

## Plot the UpSet diagram

plot( upset( upset_df, c('stanford_db20240430', 'stanford_historical', 'anderson2015'), name = 'ID source' ) )
ggsave('nctid-overlap-all.png', width = 12, height = 8)

all_ids <- unique(c(relevant_df$nctid, paper_df$NCT_ID))
upset_df <- data.frame(
	ID           = all_ids,
	stanford_historical   = all_ids %in% relevant_df$nctid,
	anderson2015 = all_ids %in% paper_df$NCT_ID
)
plot( upset( upset_df, c('stanford_historical', 'anderson2015'), name = 'ID source' ) )
ggsave('nctid-overlap-historical.png', width = 12, height = 8)
