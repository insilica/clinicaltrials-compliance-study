# if(!sys.nframe()) { source('analysis/driver-aggregate-data.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

# Map unit strings to siunitx-compatible units
map_unit <- function(unit_str) {
  unit_map <- list(
    "count" = "count",
    "percent" = "\\percent",
    "delta-percent" = "\\percent"
  )

  if (!unit_str %in% names(unit_map)) {
    stop(paste("Unknown unit:", unit_str))
  }

  return(unit_map[[unit_str]])
}

as.string <- function(v) {
  if(is.null(v)) {
    return(NA)
  }
  if(is.numeric(v)) {
    return(as.character(v))
  }
  if(is.character(v)) {
    return(v)
  }
  stop(paste("Can not convert value to string", v))
}

format.percent <- function(value) {
  return( sprintf("%.2f", value) )
}

format.delta.percent <- function(value) {
  return( sprintf("%+.2f", value) )
}

add_data <- function(df, key,
                     value = NULL,
                     value0 = NULL, value1 = NULL,
                     unit = NULL, comment = "") {

  # Convert the human-readable unit to siunitx-compatible unit
  siunitx_unit <- map_unit(unit)

  # Infer type based on provided values
  type <- if (!is.null(value0) & !is.null(value1) & is.null(value)) {
    "range"
  } else if (!is.null(value) & is.null(value0) & is.null(value1)) {
    "single"
  } else {
    stop("Either value or both value0 and value1 must be provided")
  }

  # Add the row
  df <- df |>
    add_row(
      key = key,
      value = as.string(value),
      unit = siunitx_unit,
      comment = comment,
      value0 = as.string(value0),
      value1 = as.string(value1),
      type = type
    )

  return(df)
}

# Initialize empty data frame
data <- tibble(
  key = character(),
  value = character(),
  unit = character(),
  comment = character(),
  value0 = character(),
  value1 = character(),
  type = character()
)

agg.window.compare.rule_effective <- windows.rdata.read('brick/rule-effective-date_processed')

w1 <- agg.window.compare.rule_effective[["rule-effective-date-before"]]
w2 <- agg.window.compare.rule_effective[["rule-effective-date-after"]]

agg.windows.yearly_obs36 <- windows.rdata.read('brick/yearly_obs36_processed')

add_data.window_agg.subset <- function(data,
                                       window.hlact,
                                       prefix, name,
                                       subset.prefix = '',
                                       subset.name = '' ) {
  pct.prefix <- glue("{prefix}-pct{subset.prefix}")
  pct.name   <- glue("Percentage of trials in {name} ({subset.name})")
  data <- ( data
    |> add_data(key = glue("{prefix}{subset.prefix}-hlact-count"),
                value = nrow(window.hlact),
                unit = "count",
                comment = glue("Number of trials in {name} ({subset.name})"))

    |> add_data(key = glue("{pct.prefix}-report-w-in-12-mo"),
                value = ( 100*mean(window.hlact$cr.results_reported_12mo) ) |>
                  format.percent(),
                unit  = "percent",
                comment = glue("{pct.name} that report within 12 months"))
    |> add_data(key = glue("{pct.prefix}-report-not-w-in-12-mo"),
                value = ( 100*mean( ! window.hlact$cr.results_reported_12mo ) ) |>
                  format.percent(),
                unit  = "percent",
                comment = glue("{pct.name} that did not report within 12 months"))

    |> add_data(key = glue("{pct.prefix}-report-w-in-36-mo"),
                value = ( 100*mean(window.hlact$cr.results_reported_36mo) ) |>
                  format.percent(),
                unit  = "percent",
                comment = glue("{pct.name} that report within 36 months"))
    |> add_data(key = glue("{pct.prefix}-report-not-w-in-36-mo"),
                value = ( 100*mean( ! window.hlact$cr.results_reported_36mo ) ) |>
                  format.percent(),
                unit  = "percent",
                comment = glue("{pct.name} that did not report within 36 months"))
  )
  return(data)
}

add_data.window_agg <- function(data, window.hlact, prefix, name) {
  data <- ( data
    |> add_data.window_agg.subset( window.hlact,
                                  prefix, name,
                                  subset.prefix = '', subset.name = 'all')

    # Funding subsets
    ## Funding NIH / nih
    |> add_data.window_agg.subset( window.hlact |> filter( common.funding == 'NIH' ),
                                  prefix, name,
                                  subset.prefix = '-funding-nih', subset.name = 'with NIH funding')
    ## Funding Industry / industry
    |> add_data.window_agg.subset( window.hlact |> filter( common.funding == 'Industry' ),
                                  prefix, name,
                                  subset.prefix = '-funding-industry', subset.name = 'with Industry funding')

    # Intervention type subsets
    ## Intervention Biological / Biologics / biologics
    |> add_data.window_agg.subset( window.hlact |> filter( common.intervention_type == 'Biological' ),
                                  prefix, name,
                                  subset.prefix = '-intervention-biologics', subset.name = 'for Biologics interventions')
    ## Intervention Device / device / devices
    |> add_data.window_agg.subset( window.hlact |> filter( common.intervention_type == 'Device' ),
                                  prefix, name,
                                  subset.prefix = '-intervention-devices', subset.name = 'for Devices interventions')
    ## Intervention Drug / drugs
    |> add_data.window_agg.subset( window.hlact |> filter( common.intervention_type == 'Drug' ),
                                  prefix, name,
                                  subset.prefix = '-intervention-drugs', subset.name = 'for Drugs interventions')
  )
  return(data)
}

add_data.window_yearly <- function(data) {
  for (name in names(agg.windows.yearly_obs36)) {
    w <- agg.windows.yearly_obs36[[name]]
    y.start  <- w$window$date$start  |> year()
    y.stop   <- w$window$date$stop   |> year()
    y.cutoff <- w$window$date$cutoff |> year()
    data <- ( data
      |> add_data.window_agg.subset(w$hlact.studies,
            prefix = glue("yearly-{y.start}-{y.stop}"),
            name = glue("Yearly window from {y.start} to {y.stop} with cut-off in {y.cutoff}"),
            subset.prefix = '', subset.name = 'all')
    )
  }
  return(data)
}

# Add single values
data <- ( data
  |> add_data.window_agg(window = w1$hlact.studies,
                         prefix='window1', name='Window 1')
  |> add_data.window_agg(window = w2$hlact.studies,
                         prefix='window2', name='Window 2')

  ## Add delta values
  |> add_data(key = "window1-to-2-delta-pct-report-w-in-12-mo",
              value = ( 100*(  mean(w2$hlact.studies$cr.results_reported_12mo)
                             - mean(w1$hlact.studies$cr.results_reported_12mo) ) ) |>
                      format.delta.percent(),
              unit  = "delta-percent",
              comment = "Difference between window2-pct-report-w-in-12-mo and window1-pct-report-w-in-12-mo")

  |> add_data(key = "window1-to-2-delta-pct-report-w-in-36-mo",
              value = ( 100*(  mean(w2$hlact.studies$cr.results_reported_36mo)
                             - mean(w1$hlact.studies$cr.results_reported_36mo) ) ) |>
                      format.delta.percent(),
              unit  = "delta-percent",
              comment = "Difference between window2-pct-report-w-in-36-mo and window1-pct-report-w-in-36-mo")

  |> add_data.window_yearly()

  |> add_data(key = "yearly-2015-2016-to-2016-2017-delta-pct-report-w-in-12-mo",
              value = {
                        window.for.year <- \(x.year) {
                          return(
                            agg.windows.yearly_obs36
                            |> keep( ~ .x$window$date$start |> year() == x.year )
                            |> getElement(1)
                          )
                        }
                        y2016 <- window.for.year(2016)
                        y2015 <- window.for.year(2015)
                        ( 100*(  mean(y2016$hlact.studies$cr.results_reported_12mo)
                               - mean(y2015$hlact.studies$cr.results_reported_12mo) ) )
                       } |>
                      format.delta.percent(),
              unit  = "delta-percent",
              comment = "Difference between yearly-2016-2017-pct-report-w-in-12-mo and yearly-2015-2016-pct-report-w-in-12-mo")
)

# Save the dataset
fs::dir_create("figtab/aggregate-data")
write.csv(data, "figtab/aggregate-data/data.csv", row.names = FALSE, na = "")
