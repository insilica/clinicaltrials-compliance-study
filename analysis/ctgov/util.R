add_prefix <- function(df, prefix) {
  df %>%
    rename_with(~ paste0(prefix, .))
}
