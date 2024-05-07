library(arrow)
library(DBI)
library(RPostgres)
library(dotenv)
library(dplyr)
library(readr)

library(ggplot2)
library(ComplexUpset)

dotenv::load_dot_env(".env")

conn <- dbConnect(RPostgres::Postgres(),
  dbname = "aact_20240430",
  host = Sys.getenv("PGHOST"),
  port = Sys.getenv("PGPORT"))

res <- dbSendQuery(conn, read_file('aact2024_init.sql'))
query_df <- dbFetch(res)
dbClearResult(res)

paper_df <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet')


all_ids <- unique(c(query_df$nct_id, paper_df$NCT_ID))
upset_df <- data.frame(
	ID           = all_ids,
	db20240430   = all_ids %in% query_df$nct_id,
	anderson2015 = all_ids %in% paper_df$NCT_ID
)

plot( upset( upset_df, c('db20240430', 'anderson2015'), name = 'ID source' ) )
ggsave('nctid-overlap.png', width = 12, height = 8)
