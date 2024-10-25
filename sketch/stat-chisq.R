# if(!sys.nframe()) { source('sketch/stat-chisq.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

params <- window.params.read()

params.filtered <- params |>
  window.params.filter.by.name('^rule-effective-date-(before|after)$') |>
  window.params.apply.prefix('rule-effective')
print(names(params.filtered))
agg.windows <- process.windows.init(params.filtered) |>
  process.windows.amend.results_reported()

table.count <- matrix(
            nrow = 2,
            data = c(table( ! agg.windows[['rule-effective-date-before']]$hlact.studies$rr.results_reported_12mo ),
                     table( ! agg.windows[['rule-effective-date-after']]$hlact.studies$rr.results_reported_12mo ) ),
            dimnames = list( c("Yes", "No"), c("Before", "After"))
) |> t()

table.count

table.count |> addmargins()

# Compare??
#        Yes
# Before 1148
# After  2229

# is prop1 ≠ prop2?
prop.test( table.count, alternative = 'two.sided'  )

# is prop1 (before) < prop2 (after)?
prop.test( table.count, alternative = 'less'  )

#(
#agg.windows[['rule-effective-date-before']]$hlact.studies
#  |> mutate(
#    t =
#        ( interval(common.primary_completion_date_imputed, common.results_received_date) < days(floor(12*30.44)+1) ) |>
#        replace_na(FALSE),
#  )
#) |> select('t') |> table()


### Run prop.test() by funding source
table.count.funding <- {
  funding.levels <- agg.windows[['rule-effective-date-before']]$hlact.studies$common.funding |> levels()
  result <- funding.levels |>
    map( \(level) {
      matrix(
                  nrow = 2,
                  byrow = FALSE,
                  data = c(table( ! agg.windows[['rule-effective-date-before']]$hlact.studies
                                 |> filter( common.funding == level)
                                 |> pull(rr.results_reported_12mo) ),
                           table( ! agg.windows[['rule-effective-date-after']]$hlact.studies
                                 |> filter( common.funding == level)
                                 |> pull(rr.results_reported_12mo) ) ),
                  dimnames = list( c("Yes", "No"), c("Before", "After"))
      ) |> t()
    })
  names(result) <- funding.levels
  result
}

table.count.funding

result.prop.test.funding <- table.count.funding |> map( ~ prop.test( .x , alternative = 'less'  ) )

result.prop.test.funding


(
  agg.windows
  |> process.all.agg.window.amend.agg.interval.groups( with_facet = 'common.funding' )
  |> map( ~ .x$agg.interval.groups )
  |> map( ~ .x |> filter( agg.results_reported_within == '12 months' ) )
)
