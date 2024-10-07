
#### Window processing {{{


# Read `window.params` list from YAML file.
window.params.read <- function( params_file = 'params.yaml' ) {
  params <- yaml.load_file(params_file)
  return(params)
}

# Return a filtered `window.params` list.
window.params.filter.by.prefix <- function(params, prefix) {
  params.filtered <- params$param |>
    keep( \(x) !is.null(x$prefix) && x$prefix == prefix )

  if( length(params.filtered) == 0 ) {
    stop("No windows!")
  }

  return(params.filtered)
}

window.params.filter.by.name <- function(params, name.regex) {
  params.filtered <- params$param[
               grepl(name.regex,
                     names(params$param),
                     perl = TRUE )
             ]
  return(params.filtered)
}


# Set the prefix for all the `window.params` list.
window.params.apply.prefix <- function(params, prefix) {
  for(w_name in names(params)) {
    params[[w_name]]$prefix <- prefix
  }
  return(params)
}


process.windows.init <- function(windows) {
  agg.windows <- list()
  for(w_name in names(windows)) {
    window <- windows[[w_name]]
    censor_date <- window$date$cutoff

    log_info(w_name)

    agg.windows[[w_name]]$window <- window

    all.path   <- window$output$all
    hlact.path <- window$output$`hlact-filtered`

    agg.windows[[w_name]] <- within(agg.windows[[w_name]],{
      all.studies <- arrow::read_parquet(all.path)

      hlact.studies <- arrow::read_parquet(hlact.path) |>
        tibble()

      hlact.studies <-
        standardize.jsonl_derived(hlact.studies) |>
        preprocess_data.common(start_date  = window$date$start,
                               stop_date   = window$date$stop,
                               censor_date = censor_date)
    })
  }
  return(agg.windows)
}

process.windows.amend.results_reported <- function(agg.windows) {
  for(w_name in names(agg.windows)) {
    agg.windows[[w_name]] <- within(agg.windows[[w_name]], {
      all.studies.n <- nrow(all.studies)
      hlact.studies.n <- nrow(hlact.studies)
      surv.event.n <- sum(hlact.studies$surv.event)
      rr.results_reported_12mo.n <- sum(hlact.studies$rr.results_reported_12mo)
      rr.results_reported_5yr.n  <- sum(hlact.studies$rr.results_reported_5yr )
    })
  }
  return(agg.windows)
}

process.windows.amend.model.logistic <- function(agg.windows) {
  for(w_name in names(agg.windows)) {
    agg.windows[[w_name]] <- within(agg.windows[[w_name]], {
      model.logistic <-
        logistic_regression(hlact.studies,
                            formula.jsonl_derived)
    })
  }
  return(agg.windows)
}
# }}}
