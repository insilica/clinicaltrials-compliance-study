library(lubridate)
library(ggsurvfit)
library(gtsummary)
library(tidycmprsk)
library(dotenv)
library(DBI)
library(RPostgres)
library(readr)
library(dplyr)


dotenv::load_dot_env(".env")

## Data from database

query_file <- "sql/aact2024_survival.sql"

conn <- dbConnect(RPostgres::Postgres(),
  dbname = "aact_20240430",
  host = Sys.getenv("PGHOST"),
  port = Sys.getenv("PGPORT")
)

res <- dbSendQuery(conn, read_file(query_file))
query_df <- dbFetch(res)
dbClearResult(res)


# survival time variable

add_report_time <- function(report_date, months_to_add) {
  new_date <- report_date %m+% months(months_to_add)
  new_date
}

with_dates <- query_df %>%
  mutate(
    reported = add_report_time(
      primary_completion_date,
      months_to_report_results
    )
  )

# calculated survival time

survival_calculated <- with_dates %>%
  mutate(
    os_date = lubridate::as.duration(primary_completion_date %--% reported) /
      dyears(1)
  )

# Perform survival analysis
survfit_obj <- survfit(Surv(os_date, were_results_reported) ~ 1,
  data = survival_calculated
)

# Plot the survival curve
survfit_obj %>% ggsurvfit() +
  labs(x = "Months", y = "Overall survival probability")

