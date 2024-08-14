if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( lubridate, glue )

# Generate sliding time periods and format as YAML
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
