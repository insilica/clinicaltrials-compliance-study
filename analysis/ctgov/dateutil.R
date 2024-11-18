pacman::p_load(
  dplyr
)

# Functions to create date from year and month
create_date_w_mfmt <- function(year, month, month_fmt) {
  date_fmt <- paste("%Y", month_fmt, "%d", sep = "-")
  if_else(!is.na(year) & !is.na(month),
          as.Date(paste(year, month, "01", sep = "-"), format = date_fmt),
          NA)
}

create_date_month_name <- function(year, month) {
  create_date_w_mfmt(year, month, "%B")
}

create_date_month_int <- function(year, month) {
  create_date_w_mfmt(year, month, "%m")
}

create_date_partial <- function(date_string) {
  parse_date_time(date_string, c('ymd', 'ym'))
}

# Results reported within an interval (inclusive).
dateproc.results_reported.within_inc <- function(data, period) {
  if(period < days(1)) {
    stop("Period must be greater than days(1).")
  }
  return (with(data, {
        ( interval(common.primary_completion_date_imputed, common.results_received_date) < period + days(1) ) |>
        replace_na(FALSE)
  }))
}
