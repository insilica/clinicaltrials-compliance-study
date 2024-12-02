
### Plot compare logistic {{{

plot.windows.compare.logistic <- function(agg.windows) {
  for(name in names(agg.windows)) {
    with(agg.windows[[name]],{
      model <- model.logistic
      log_info(name)
      log_info(str.print(model))
      fig <- compare.model.logistic( model ) |>
        plot.compare.logistic()
      fig <- fig + labs(title = name)
      show(fig)
      #invisible(readline(prompt="Press [enter] to continue"))
      plot.output.base <- fs::path(glue("figtab/{agg.windows[[1]]$window$prefix}/{window$suffix}/compare.table_s7.or"))
      fs::dir_create(path_dir(plot.output.base))
      for (ext in c("png", "svg", "pdf")) {
        ggsave(paste0(plot.output.base, ".", ext), width = 12, height = 8)
      }
    })
  }
}
# }}}
