# if(!sys.nframe()) { source('sketch/anderson2015-compare.R') }

if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger )

source('analysis/ctgov.R')

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

# NCT IDs
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

{
original.nctids <- anderson2015.original$hlact.studies$nctid
new.nctids <- anderson2015.new$hlact.studies$nctid

intersect.nctids <- intersect(original.nctids, new.nctids)
intersect.nctids |> length()
setdiff(original.nctids, new.nctids) |> length()
setdiff(new.nctids, original.nctids) |> length()
#----------------------------------------------------------------
#| > intersect.nctids <- intersect(original.nctids, new.nctids) |
#| > intersect.nctids |> length()                               |
#| [1] 11237                                                    |
#| > setdiff(original.nctids, new.nctids) |> length()           |
#| [1] 2090                                                     |
#| > setdiff(new.nctids, original.nctids) |> length()           |
#| [1] 3436                                                     |
#----------------------------------------------------------------
}

# Join dataframes
df.joined <- ( anderson2015.original$hlact.studies
  |> inner_join( anderson2015.new$hlact.studies, by = 'nctid' )
)

# Compare original and new: on the lead sponsors variable.
# This is expected to align closely because there is no processing other than
# mapping to "Other" here.
table(
  df.joined$schema0.agency_classc,
  df.joined$schema1.lead_sponsor_funding_source
    |> standardize.jsonl_derived.norm.funding_source()
) |> addmargins()
############################################################
# > table(                                                 #
# +   df.joined$schema0.agency_classc,                     #
# +   df.joined$schema1.lead_sponsor_funding_source        #
# +     |> standardize.jsonl_derived.norm.funding_source() #
# + ) |> addmargins()                                      #
#                                                          #
#            Industry   NIH Other   Sum                    #
#   Industry     5854     0     1  5855                    #
#   NIH             1   608     5   614                    #
#   Other           9     4  4583  4596                    #
#   U.S. Fed        0     0   172   172                    #
#   Sum          5864   612  4761 11237                    #
############################################################

# Compare original and new: after data normalization
# (lead sponsor + collaborators).
# There is processing here. This is to test that the processing done is
# replicated.
table(
      df.joined$common.funding.x,
      df.joined$common.funding.y
) |> addmargins()
#########################################
# > table(                              #
# +       df.joined$common.funding.x,   #
# +       df.joined$common.funding.y    #
# + ) |> addmargins()                   #
#                                       #
#            Industry   NIH Other   Sum #
#   Industry     7249     1     1  7251 #
#   NIH           104  1681     0  1785 #
#   Other          24     1  2176  2201 #
#   Sum          7377  1683  2177 11237 #
#########################################


################################################################################

# Compare new with itself: lead sponsor variable with normalized data from lead
# sponsor and collaborators.
#
# This is to show how many are reassigned from "Other" in the
# `schema1.lead_sponsor_funding_source` to "Industry" or "NIH" due to
# the `schema1.collaborators_classes`.
table(
      df.joined$schema1.lead_sponsor_funding_source
        |> standardize.jsonl_derived.norm.funding_source(),
      df.joined$common.funding.y
) |> addmargins()
#################################################################
# > table(                                                      #
# +       df.joined$schema1.lead_sponsor_funding_source         #
# +         |> standardize.jsonl_derived.norm.funding_source(), #
# +       df.joined$common.funding.y                            #
# + ) |> addmargins()                                           #
#                                                               #
#            Industry   NIH Other   Sum                         #
#   Industry     5864     0     0  5864                         #
#   NIH             0   612     0   612                         #
#   Other        1513  1071  2177  4761                         #
#   Sum          7377  1683  2177 11237                         #
#################################################################

# This shows the off-diagnoals (where original and new disagree).
( df.joined
  #
  |> filter(
    common.funding.x != common.funding.y
  )
  #
  |> select( 'nctid', 'common.funding.x', 'common.funding.y' )
  #
  |> (\(x) table(x$common.funding.x, x$common.funding.y) )()
)


# The off-diagnoals that were not reassigned from "Other" are likely due to the
# `schema1.collaborators_classes` in the new data not being the same.
( df.joined
  #
  |> mutate(
      str.collaborator_classes =
        schema1.collaborators_classes
          |> map_chr( ~ paste(.x, collapse = '-') )
          |> as.factor(),
      str.lead_sponsor_funding =
        schema1.lead_sponsor_funding_source
          |> standardize.jsonl_derived.norm.funding_source()
  )
  #
  |> filter(
    common.funding.x != common.funding.y,
    schema0.agency_classc     != 'Other',
    schema1.lead_sponsor_funding_source  != 'OTHER',
  )
  |> select(
            'nctid',
            'common.funding.x',
            'schema0.agency_classc',
            #'schema0.sponsor_name',
            #'schema0.collaborator_names',
            'common.funding.y',
            'schema1.lead_sponsor_funding_source',
            #'str.lead_sponsor_funding',
            #'schema1.lead_sponsor_name',
            'str.collaborator_classes',
  )
  #
) |> print(n=30, width = 800)

### Comment: There are only 3 where this is the case.
###
### For one of these (NCT00422201), the lead sponsors do not match.
###
### For two of these (NCT00470418, NCT01076452),
### the original data assigns these to NIH, but since they
### have an INDUSTRY collaborator, `common.funding.y` = "Industry".
#########################################################################
# # A tibble: 3 × 6                                                     #
#   nctid       common.funding.x schema0.agency_classc common.funding.y #
#   <chr>       <fct>            <chr>                 <fct>            #
# 1 NCT00422201 NIH              NIH                   Industry         #
# 2 NCT00470418 NIH              U.S. Fed              Industry         #
# 3 NCT01076452 NIH              U.S. Fed              Industry         #
#   schema1.lead_sponsor_funding_source str.collaborator_classes        #
#   <fct>                               <fct>                           #
# 1 INDUSTRY                            ""                              #
# 2 FED                                 "INDUSTRY-NIH"                  #
# 3 FED                                 "INDUSTRY-NIH"                  #
#########################################################################




  #|> filter(
  #  common.funding.x == common.funding.y
  # !( common.funding.x == 'NIH' | common.funding.y == 'NIH' ),
  # !( common.funding.x == 'Other' | common.funding.y == 'Other' ),
  #  common.funding.x != 'Other',
  #  common.funding.y != 'Other',
  #)

  #|> nrow()

  #|> names() %>% grep('funding', ., value = TRUE)

  #|> summary()
