# if(!sys.nframe()) { source('sketch/anderson2015-compare-nctids.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

### Prepare the data {{{
params_file <- 'params.yaml'
params <- yaml.load_file(params_file)

anderson2015.original <- list(
  window        = anderson2015.window(),
  hlact.studies = anderson2015.read_and_process()
)
anderson2015.original$window['prefix'] <- 'anderson2015.original'
agg.windows.original <- list(
     anderson2015.original = anderson2015.original
)
anderson2015.new.windows <- params$param['anderson2015_2008-2012']
anderson2015.new.agg.windows <- process.windows.init(anderson2015.new.windows) |>
  process.windows.amend.results_reported()
anderson2015.new.agg.windows[[1]]$window$prefix <- 'anderson2015.new'
print(names( anderson2015.new.agg.windows ))
names(anderson2015.new.agg.windows) <- c('anderson2015.new')
anderson2015.new <- anderson2015.new.agg.windows[[1]]
### }}}

### Process original and new NCT IDs {{{
anderson2015.original$hlact.studies$schema0.nct_id |> head() |> print()
anderson2015.new$hlact.studies$schema1.nct_id      |> head() |> print()

# Add column of NCT IDs (for joining)
anderson2015.original$hlact.studies <-
  anderson2015.original$hlact.studies |>
    mutate(
           nctid = schema0.nct_id
    )
anderson2015.new$hlact.studies <-
  anderson2015.new$hlact.studies |>
    mutate(
           nctid = schema1.nct_id
    )

original.nctids <- anderson2015.original$hlact.studies$nctid
new.nctids <- anderson2015.new$hlact.studies$nctid

intersect.nctids <- intersect(original.nctids, new.nctids)
intersect.nctids |> length()

nctids.only.original <- setdiff(original.nctids, new.nctids)
nctids.only.original |> length()
nctids.only.new      <- setdiff(new.nctids, original.nctids)
nctids.only.new |> length()
######################################
# > intersect.nctids |> length()     #
# [1] 11237                          #
# > nctids.only.original |> length() #
# [1] 2090                           #
# > nctids.only.new |> length()      #
# [1] 3436                           #
######################################

# NCTIDs that are not present in the new data (there are a handful that got
# their NCTIDs renamed)
setdiff(nctids.only.original,
        anderson2015.new$all.studies$nct_id
       ) |> length()
#################################################
# > setdiff(nctids.only.original,               #
# +         anderson2015.new$all.studies$nct_id #
# +        ) |> length()                        #
# [1] 50                                        #
#################################################

### }}}

### Compare original and new hlact.studies data {{{
hlact.studies.only.original <-
  anderson2015.original$hlact.studies |>
  filter(
         nctid %in% nctids.only.original
         & nctid %in% anderson2015.new$all.studies$nct_id
  )

hlact.studies.only.new <-
  anderson2015.new$hlact.studies |>
  filter(
         nctid %in% nctids.only.new
  )

summary(hlact.studies.only.original$common.start_date |> as.Date() )
summary(hlact.studies.only.new     $common.start_date |> as.Date() )

summary(hlact.studies.only.original$common.phase)
summary(hlact.studies.only.new     $common.phase)

summary(hlact.studies.only.original$common.overall_status)
summary(hlact.studies.only.new     $common.overall_status)

head(nctids.only.original)
head(nctids.only.new)
### }}}

### Use NCTIDs only in the original to compare against all.studies from new {{{
anderson2015.original$hlact.studies <-
  anderson2015.original$hlact.studies |>
    mutate(
           nctid = schema0.nct_id
    )

anderson2015.new.with.original.only <- (
  anderson2015.new
    |>
      (\(x) {
        x <- within(x,{
          all.studies <- all.studies |>
             filter(
                    nct_id %in% nctids.only.original
             )
        })
        return(x)
      })()
    |>
      (\(x) {
        x <- within(x,{
          df.proc <-
            standardize.jsonl_derived(all.studies) |>
            preprocess_data.common(start_date  = window$date$start,
                                   stop_date   = window$date$stop,
                                   censor_date = window$date$cutoff)
        })
        return(x$df.proc)
      })()
    |> mutate(
              nctid = schema1.nct_id
    )
)

# Join dataframes
df.joined <- ( anderson2015.original$hlact.studies
  |> inner_join( anderson2015.new.with.original.only, by = 'nctid' )
)
### }}}

### Compare the common. fields {{{

df.joined |> filter(common.primary_completion_date_imputed.x!= common.primary_completion_date_imputed.y  ) |> nrow()
# > df.joined |> filter(common.primary_completion_date_imputed.x!= common.primary_completion_date_imputed.y  ) |> nrow()
# [1] 9
df.joined |> filter(common.results_received_date.x          != common.results_received_date.y            ) |> nrow()
# > df.joined |> filter(common.results_received_date.x          != common.results_received_date.y          ) |> nrow()
# [1] 704
df.joined |> filter(common.start_date.x                     != common.start_date.y                       ) |> nrow()
# > df.joined |> filter(common.start_date.x                     != common.start_date.y                     ) |> nrow()
# [1] 3
df.joined |> filter(common.intervention_type.x              != common.intervention_type.y                ) |> nrow()
# > df.joined |> filter(common.intervention_type.x              != common.intervention_type.y              ) |> nrow()
# [1] 3
df.joined |> filter(common.phase.x                          != common.phase.y                            ) |> nrow()
# > df.joined |> filter(common.phase.x                          != common.phase.y                          ) |> nrow()
# [1] 0
#df.joined |> filter(common.overall_status.x                 != common.overall_status.y                   ) |> nrow()
# > #df.joined |> filter(common.overall_status.x                 != common.overall_status.y                ) |> nrow()
df.joined |> filter(common.funding.x                        != common.funding.y                          ) |> nrow()
# > df.joined |> filter(common.funding.x                        != common.funding.y                        ) |> nrow()
# [1] 13
df.joined |> filter(common.primary_purpose.x                != common.primary_purpose.y                  ) |> nrow()
# > df.joined |> filter(common.primary_purpose.x                != common.primary_purpose.y                ) |> nrow()
# [1] 0
df.joined |> filter(common.enrollment.x                     != common.enrollment.y                       ) |> nrow()
# > df.joined |> filter(common.enrollment.x                     != common.enrollment.y                     ) |> nrow()
# [1] 5
df.joined |> filter(common.oversight.x                      != common.oversight.y                        ) |> nrow()
# > df.joined |> filter(common.oversight.x                      != common.oversight.y                      ) |> nrow()
# [1] 0
df.joined |> filter(common.allocation.x                     != common.allocation.y                       ) |> nrow()
# > df.joined |> filter(common.allocation.x                     != common.allocation.y                     ) |> nrow()
# [1] 2
df.joined |> filter(common.number_of_arms.x                 != common.number_of_arms.y                   ) |> nrow()
# > df.joined |> filter(common.number_of_arms.x                 != common.number_of_arms.y                 ) |> nrow()
# [1] 29
df.joined |> filter(common.masking.x                        != common.masking.y                          ) |> nrow()
# > df.joined |> filter(common.masking.x                        != common.masking.y                        ) |> nrow()
# [1] 1
df.joined |> filter(common.phase.norm.x                     != common.phase.norm.y                       ) |> nrow()
# > df.joined |> filter(common.phase.norm.x                     != common.phase.norm.y                     ) |> nrow()
# [1] 1
df.joined |> filter(common.pc_year_imputed.x                != common.pc_year_imputed.y                  ) |> nrow()
# > df.joined |> filter(common.pc_year_imputed.x                != common.pc_year_imputed.y                ) |> nrow()
# [1] 5


# What are the counts + levels for each overall_status variable?
df.joined |> select(common.overall_status.x) |> summary()
df.joined |> select(common.overall_status.y) |> summary()

# Make the levels match each other then find where they are not the same
(df.joined
  |> mutate(
            common.overall_status.x =
              common.overall_status.x
              |> fct_expand(levels(common.overall_status.y)),
            common.overall_status.y =
              common.overall_status.y
              |> fct_expand(levels(common.overall_status.x))
  )
  |> filter(common.overall_status.x                 != common.overall_status.y                )
  |> select( nctid, common.overall_status.x, common.overall_status.y )
  |> nrow()
)
# [1] 3


(df.joined
 |> mutate(across(c(schema1.study_type, common.overall_status.y), as.factor) )
 |> select(schema1.study_type, common.overall_status.y) |> summary())

(df.joined
 |> select(schema1.is_fda_regulated_drug, schema1.is_fda_regulated_device) |> summary())

(anderson2015.new$all.studies
 |> select(is_fda_regulated_drug, is_fda_regulated_device) |> summary())

(df.joined
  |> mutate(
      schema0.p_completion_date = create_date_month_name(schema0.p_completion_year, schema0.p_completion_month),
        schema0.completion_date = create_date_month_name(  schema0.completion_year,   schema0.completion_month),
      schema0.verification_date = create_date_month_name(schema0.verification_year, schema0.verification_month)
  )
  |> filter(
            #!
            ( common.primary_completion_date_imputed.y >= as.Date('2008-01-01')
            & common.primary_completion_date_imputed.y < as.Date('2012-09-01')
            ) # POS: 2034 NEG: 6
            #(
            ## common.primary_completion_date_imputed.x == as.Date('2008-01-01')
            ##|
            ##  common.primary_completion_date_imputed.x >= as.Date('2012-08-01')
            ##& common.primary_completion_date_imputed.x <= as.Date('2012-09-01')
            #)
     )
  |> filter(
            #schema1.overall_status != 'WITHDRAWN'  ,# 2034
            #schema1.study_type == 'INTERVENTIONAL' ,# 2033
            #schema1.has_us_facility                ,# 85
            ( schema1.is_fda_regulated_drug        # 0
            | schema1.is_fda_regulated_device      # 0
            )
  )
  #|> select(nctid,
  #          starts_with('common.primary_completion_date_imputed.'),
  #          #matches('schema1\\..*date')
  #          #matches('schema0\\..*date'),
  #          #matches('common\\..*date.x')
  #   )
#)  |> print(n=10)
)  |> nrow()

### Regression {{{
(model.logistic.original.with.original.only <-
  logistic_regression(hlact.studies.only.original,
                      formula.anderson2015)
)
model.logistic.original.with.original.only |> print(n=50)

(model.logistic.new.with.original.only <-
  logistic_regression(anderson2015.new.with.original.only,
                      formula.jsonl_derived)
)
model.logistic.new.with.original.only |> print(n=50)
### }}}

table(
  df.joined$common.primary_purpose.x |> fct_relevel(sort),
  df.joined$common.primary_purpose.y |> fct_relevel(sort)
) |> addmargins() |> print( width = 200)

table(
  df.joined$common.intervention_type.x |> fct_relevel(sort),
  df.joined$common.intervention_type.y |> fct_relevel(sort)
) |> addmargins() |> print( width = 200)

hlact.studies.only.original$common.intervention_type |> summary()
anderson2015.new.with.original.only$common.intervention_type |> summary()

### }}}

# vim:fdm=marker
