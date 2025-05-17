
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

# Add the compliance columns with and without extensions
process.windows.amend.compliance_extensions <- function(agg.windows) {
  for(w_name in names(agg.windows)) {
    agg.windows[[w_name]] <- within(agg.windows[[w_name]], {
      # Add compliance columns for with and without extensions

      # Compliance with extensions - using cr.interval_to_results_with_extensions_no_censor
      hlact.studies <- hlact.studies |>
        mutate(
          # Set default interval to with extensions
          cr.interval_to_results_default = cr.interval_to_results_with_extensions_no_censor,
          # Calculate compliance with extensions (within 12 months)
          cc.compliant_with_extensions = dateproc.results_reported.within_inc(pick(everything()), months(12))
        )

      # Compliance without extensions - using cr.interval_to_results_no_extensions_no_censor
      hlact.studies <- hlact.studies |>
        mutate(
          # Reset default interval to no extensions
          cr.interval_to_results_default = cr.interval_to_results_no_extensions_no_censor,
          # Calculate compliance without extensions (within 12 months)
          cc.compliant_no_extensions = dateproc.results_reported.within_inc(pick(everything()), months(12))
        )
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

windows.hlact.write <- function(dirpath, agg.windows) {
  fs::dir_create(dirpath)
  for (name in agg.windows %>% names) {
    #prefix_file <- gsub('-', '', name %>% substrRight(11))
    prefix_file <- gsub('-', '', name %>% str_sub(start = -11))
    file_name <- paste(prefix_file, 'hlact_studies.parquet', sep='_')
    path2 <- file.path(dirpath, file_name)
    agg.windows[[name]]$hlact.studies %>% write_parquet(path2)
  }
}

windows.rdata.write <- function(dirpath, agg.windows) {
  fs::dir_create(dirpath)
  save(agg.windows, file = file.path(dirpath, 'agg.windows.Rdata'))
}

windows.rdata.read <- function(dirpath, agg.windows) {
  load(file.path(dirpath, 'agg.windows.Rdata'))
  return(agg.windows)
}

# }}}
