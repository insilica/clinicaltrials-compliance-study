add_prefix <- function(df, prefix) {
  df %>%
    rename_with(~ paste0(prefix, .))
}

str.print <- function(input, ...) {
  output <- capture.output(print(input, ...))
  output_str <- paste(output, collapse = "\n")
  return(output_str)
}
