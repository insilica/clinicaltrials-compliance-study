# source('analysis/generate-sliding-window.R')

source('analysis/ctgov/sliding_window.R')

start_date <- '2008-01-01'
slide_months <- 56/2
n_iterations <- 5
period_length_months <- 56
cutoff_addend <- months(12)
prefix <- 'sliding-window'

yaml_output <-
  generate_time_periods_yaml(start_date           = start_date,
                             slide_months         = slide_months,
                             n_iterations         = n_iterations,
                             period_length_months = period_length_months,
                             cutoff_addend        = cutoff_addend,
                             prefix               = prefix)

# Print the generated YAML output
cat(paste0(yaml_output,"\n"))
