standardize.jsonl_derived <- function(df) {
  df |>
    add_prefix('schema1.')
}
