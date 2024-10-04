if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( lubridate, glue )

# Generate sliding time periods and format as YAML

#' Generate Sliding Time Periods and Format as YAML
#'
#' This function generates a list of sliding time periods, formats them as YAML, and returns
#' the formatted output. Each time period is defined by a start date, duration, and a cutoff date.
#' The function creates period names and paths dynamically and includes output file paths.
#'
#' @param start_date A string representing the starting date for the first period.
#'   It should be in a format parseable by `ymd` (from the `lubridate` package).
#' @param slide_months A numeric value indicating the number of months the sliding window
#'   moves forward for each iteration.
#' @param n_iterations An integer specifying the number of time periods (iterations) to generate.
#' @param period_length_months A numeric value representing the length of each time period in months.
#'   Defaults to 56 months.
#' @param cutoff_addend A duration (from the `lubridate` package), added to the stop date of each period
#'   to determine the cutoff date. Defaults to `months(12)`.
#' @param prefix A string used as the prefix in the generated period names and directory paths.
#'   Defaults to 'sliding-window'.
#'
#' @return A YAML-formatted string with the sliding time periods, including the start, stop, and
#'   cutoff dates, as well as file paths for output data.
#'
#' @examples
#' \dontrun{
#'   generate_time_periods_yaml("2023-01-01", 6, 5)
#' }
#'
generate_time_periods_yaml <- function(start_date,
                                       slide_months,
                                       n_iterations,
                                       period_length_months = 56,
                                       cutoff_addend = months(12),
                                       prefix = 'sliding-window') {

  start_date <- ymd(start_date)

  periods <- list()

  for (i in 1:n_iterations) {
    period_start  <- start_date   %m+% months((i-1) * slide_months)
    period_stop   <- period_start %m+% months(period_length_months)
    period_cutoff <- period_stop  %m+% cutoff_addend

    period_name.cutoff <- format(period_cutoff, '%Y%m%d')

    period_name <- glue("{prefix}_n-{i}_{period_name.cutoff}")
    suffix      <- glue("n-{i}_{period_name.cutoff}")
    period_path <- fs::path_join(c(
                     glue("{prefix}"),
                     glue("{suffix}")))
    periods[[period_name]] <- list(
      n      = i,
      prefix = prefix,
      suffix = suffix,
      cutoff = format(period_cutoff, "%Y-%m-%d"),
      start  = format(period_start, "%Y-%m-%d"),
      stop   = format(period_stop, "%Y-%m-%d"),
      dir    = period_path
    )
  }

  yaml_output <- ""

  for (period_name in names(periods)) {
    period <- periods[[period_name]]
    yaml_output <- glue("{yaml_output}
{period_name}:
  prefix: {period$prefix}
  suffix: {period$suffix}
  n: {period$n}
  date:
    cutoff: '{period$cutoff}'
    start:  '{period$start}'
    stop:   '{period$stop}'
  output:
    all:            brick/{period$dir}/ctgov-studies-all.parquet
    hlact-filtered: brick/{period$dir}/ctgov-studies-hlact.parquet")
  }

  yaml_output <- gsub('(?m)\\A\n','',
                      yaml_output, perl=TRUE)
  yaml_indent <- gsub('(?m)^',
                      paste0(rep(' ', 2),collapse=''),
                      yaml_output, perl=TRUE)
  return(yaml_indent)
}
