
#### Plot scatterline {{{

plot.pct.scatterline <- function(data, y.var, title) {
  fig <- ( ggplot(data, aes(x = cutoff, y = {{y.var}}, group = 1))
    + geom_line()
    + geom_point( size = 2)
    + scale_y_continuous()
    + labs(x = 'Cut-off date', y = 'Percentage')
    + ggtitle(title)
    + theme_minimal()
    + theme(axis.text.x = element_text(angle = 45, hjust = 1))
  )

  return(fig)
}

plot.windows.pct.scatterline <- function(agg.windows) {
  df <- agg.windows |>
    map( ~ data.frame(
             cutoff = .x$window$date$cutoff,
             hlact.n    = .x$hlact.studies.n,
             hlact.pct  = .x$hlact.studies.n / .x$all.studies.n,
             rr.results_reported_12mo.n   =
               .x$rr.results_reported_12mo.n,
             rr.results_reported_12mo.pct =
               .x$rr.results_reported_12mo.n / .x$hlact.studies.n,
             rr.results_reported_5yr.n   =
               .x$rr.results_reported_5yr.n,
             rr.results_reported_5yr.pct =
               .x$rr.results_reported_5yr.n / .x$hlact.studies.n
             ) ) |>
    list_rbind() |> tibble()

  fig.pct.all <-
  (  plot.pct.scatterline(df, rr.results_reported_12mo.pct,
                        'Percentage results reported within 12 months')
   + plot.pct.scatterline(df, rr.results_reported_5yr.pct,
                         'Percentage results reported within 5 years')
   + plot.pct.scatterline(df, hlact.pct,
                         'Percentage HLACTs out of all studies')
  )
  show(fig.pct.all)
  plot.output.path <- fs::path(glue("figtab/{agg.windows[[1]]$window$prefix}/fig.percentage.all.png"))
  fs::dir_create(path_dir(plot.output.path))
  ggsave(plot.output.path, width = 12, height = 8)
}
# }}}
