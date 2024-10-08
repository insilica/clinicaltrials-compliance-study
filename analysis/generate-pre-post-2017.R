# source('analysis/generate-yearly-window.R')

source('analysis/ctgov/sliding_window.R')

start_date <- '2013-01-01'
slide_months <- 4*12
years_after_stop <- 3
n_iterations <- 2 # (2024-2013 - years_after_stop)
period_length_months <- 4*12
cutoff_addend <- months(years_after_stop*12)
prefix <- 'pre-post-2017'

yaml_output <-
  generate_time_periods_yaml(start_date           = start_date,
                             slide_months         = slide_months,
                             n_iterations         = n_iterations,
                             period_length_months = period_length_months,
                             cutoff_addend        = cutoff_addend,
                             prefix               = prefix)

# Print the generated YAML output
cat(paste0(yaml_output,"\n"))

