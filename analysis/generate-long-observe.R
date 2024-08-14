# source('analysis/generate-long-observe.R')

source('analysis/ctgov/sliding_window.R')

start_date <- '2013-01-01'
slide_months <- 2*12
n_iterations <- 3
period_length_months <- 2*12
cutoff_addend <- months(5*12)
prefix <- 'long-observe'

yaml_output <-
  generate_time_periods_yaml(start_date           = start_date,
                             slide_months         = slide_months,
                             n_iterations         = n_iterations,
                             period_length_months = period_length_months,
                             cutoff_addend        = cutoff_addend,
                             prefix               = prefix)

# Print the generated YAML output
cat(paste0(yaml_output,"\n"))
