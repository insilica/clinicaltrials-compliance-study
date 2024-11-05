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

( agg.windows <-
    agg.windows
    |> list_rename(
                   Before = 'rule-effective-date-before',
                   After  = 'rule-effective-date-after',
    )
)

table.count <- matrix(
            nrow = 2,
            data = unlist(agg.windows |> map( ~ table( ! .x$hlact.studies$rr.results_reported_12mo ) )),
            dimnames = list( c("Yes", "No"), names(agg.windows) )
) |> t()

table.count

table.count |> addmargins()
#################################
# > table.count |> addmargins() #
#         Yes    No   Sum       #
# Before 1170 13004 14174       #
# After  2292  7588  9880       #
# Sum    3462 20592 24054       #
#################################

# Compare??
#        Yes
# Before 1148
# After  2229

# is prop1 ≠ prop2?
prop.test( table.count, alternative = 'two.sided'  )
################################################################################
# > # is prop1 ≠ prop2?                                                        #
# > prop.test( table.count, alternative = 'two.sided'  )                       #
#                                                                              #
#         2-sample test for equality of proportions with continuity correction #
#                                                                              #
# data:  table.count                                                           #
# X-squared = 1054, df = 1, p-value < 2.2e-16                                  #
# alternative hypothesis: two.sided                                            #
# 95 percent confidence interval:                                              #
#  -0.1590004 -0.1398762                                                       #
# sample estimates:                                                            #
#     prop 1     prop 2                                                        #
# 0.08254551 0.23198381                                                        #
################################################################################

# is prop1 (before) < prop2 (after)?
prop.test( table.count, alternative = 'less'  )
################################################################################
# > # is prop1 (before) < prop2 (after)?                                       #
# > prop.test( table.count, alternative = 'less'  )                            #
#                                                                              #
#         2-sample test for equality of proportions with continuity correction #
#                                                                              #
# data:  table.count                                                           #
# X-squared = 1054, df = 1, p-value < 2.2e-16                                  #
# alternative hypothesis: less                                                 #
# 95 percent confidence interval:                                              #
#  -1.0000000 -0.1413997                                                       #
# sample estimates:                                                            #
#     prop 1     prop 2                                                        #
# 0.08254551 0.23198381                                                        #
################################################################################

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
  funding.levels <- agg.windows[['Before']]$hlact.studies$common.funding |> levels()
  result <- funding.levels |>
    map( \(level) {
      matrix(
                  nrow = 2,
                  data = unlist(
                                agg.windows |> map( \(window) {
                                  table( ! window$hlact.studies
                                        |> filter( common.funding == level)
                                        |> pull(rr.results_reported_12mo) )
                                })
                  ),
                  dimnames = list( c("Yes", "No"), names(agg.windows) )
      ) |> t()
    })
  names(result) <- funding.levels
  result
}

table.count.funding
#########################
# > table.count.funding #
# $Industry             #
#         Yes   No      #
# Before  687 6027      #
# After  1198 2606      #
#                       #
# $NIH                  #
#        Yes   No       #
# Before 205 2429       #
# After  292  615       #
#                       #
# $Other                #
#        Yes   No       #
# Before 278 4548       #
# After  802 4367       #
#########################

result.prop.test.funding <- table.count.funding |> map( ~ prop.test( .x , alternative = 'less'  ) )

result.prop.test.funding
################################################################################
# > result.prop.test.funding                                                   #
# $Industry                                                                    #
#                                                                              #
#         2-sample test for equality of proportions with continuity correction #
#                                                                              #
# data:  .x                                                                    #
# X-squared = 744.73, df = 1, p-value < 2.2e-16                                #
# alternative hypothesis: less                                                 #
# 95 percent confidence interval:                                              #
#  -1.0000000 -0.1986014                                                       #
# sample estimates:                                                            #
#    prop 1    prop 2                                                          #
# 0.1023235 0.3149317                                                          #
#                                                                              #
#                                                                              #
# $NIH                                                                         #
#                                                                              #
#         2-sample test for equality of proportions with continuity correction #
#                                                                              #
# data:  .x                                                                    #
# X-squared = 331.2, df = 1, p-value < 2.2e-16                                 #
# alternative hypothesis: less                                                 #
# 95 percent confidence interval:                                              #
#  -1.0000000 -0.2164473                                                       #
# sample estimates:                                                            #
#    prop 1    prop 2                                                          #
# 0.0778284 0.3219405                                                          #
#                                                                              #
#                                                                              #
# $Other                                                                       #
#                                                                              #
#         2-sample test for equality of proportions with continuity correction #
#                                                                              #
# data:  .x                                                                    #
# X-squared = 245.42, df = 1, p-value < 2.2e-16                                #
# alternative hypothesis: less                                                 #
# 95 percent confidence interval:                                              #
#  -1.00000000 -0.08739864                                                     #
# sample estimates:                                                            #
#     prop 1     prop 2                                                        #
# 0.05760464 0.15515574                                                        #
################################################################################


(
  agg.windows
  |> process.all.agg.window.amend.agg.interval.groups( with_facet = 'common.funding' )
  |> map( ~ .x$agg.interval.groups )
  |> map( ~ .x |> filter( agg.results_reported_within == '12 months' ) )
)
