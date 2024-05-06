library(cthist)
library(arrow)
library(DBI)
library(RPostgres)
library(dotenv)
library(dplyr)
library(doFuture)
library(fs)

plan(multisession)

fs::dir_create("work")
dotenv::load_dot_env(".env")

download_ct_data <- function(ctid) {
  filename <- paste0("work/", ctid, ".parquet")
  if (!fs::file_exists(filename) || fs::is_file_empty(filename)) {
    print(paste("Fetching", ctid))
    data <- clinicaltrials_gov_download(ctid)
    print(paste("Fetched", ctid))
    arrow::write_parquet(data, filename)
  }
}

conn <- dbConnect(RPostgres::Postgres(),
  dbname = "aact_20240430",
  host = Sys.getenv("PGHOST"),
  port = Sys.getenv("PGPORT"))

df <- tbl(conn, I("ctgov.studies"))

nct_ids <- dplyr::pull(df, c("nct_id"))

trial_data <- foreach(id = nct_ids) %dofuture% {
  print(id)
  download_ct_data(id)
}
