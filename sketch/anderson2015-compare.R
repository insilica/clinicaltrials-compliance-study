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


df.intersect.orig <- anderson2015.original$hlact.studies[ original.nctids %in% intersect.nctids , ]
df.intersect.new  <- anderson2015.new$hlact.studies[ new.nctids %in% intersect.nctids , ]

# Table of input data
table(
      df.intersect.orig$schema0.funding,
      df.intersect.new$schema1.lead_sponsor_funding_source
) |> addmargins()
# Table of data normalization
table(
      df.intersect.orig$common.funding,
      df.intersect.new$common.funding
) |> addmargins()
#-----------------------------------------------------------------------
#| # Table of data+ ) |> addmargins()                                  |
#|  normalization                                                      |
#| table(                                                              |
#|       df.intersect.orig$common.funding,                             |
#|       df.intersect.new$common.funding                               |
#| ) |> addmarg                                                        |
#|              FED INDIV INDUSTRY NETWORK   NIH OTHER OTHER_GOV   Sum |
#|   Industry   113    34     3803     151   393  2750         7  7251 |
#|   NIH         33     5      948      44    92   663         0  1785 |
#|   Other       32    11     1113      55   127   862         1  2201 |
#|   Sum        178    50     5864     250   612  4275         8 11237 |
#| > # Table of data normalization                                     |
#| > table(                                                            |
#| +       df.intersect.orig$common.funding,                           |
#| +       df.intersect.new$common.funding                             |
#| + ) |> addmargins()                                                 |
#|                                                                     |
#|            Industry   NIH Other   Sum                               |
#|   Industry     3803   393  3055  7251                               |
#|   NIH           948    92   745  1785                               |
#|   Other        1113   127   961  2201                               |
#|   Sum          5864   612  4761 11237                               |
#| >                                                                   |
#-----------------------------------------------------------------------

( df.intersect.orig
  |> inner_join( df.intersect.new, by = 'nctid' )
  #
  |> filter(
    common.funding.x != common.funding.y
  )
  #
  |> select( 'nctid', 'common.funding.x', 'common.funding.y' )
  #
  |> (\(x) table(x$common.funding.x, x$common.funding.y) )()
)
#--------------------------------------------------------------------
#| > ( df.intersect.orig                                            |
#| +   |> inner_join( df.intersect.new, by = 'nctid' )              |
#| +   #                                                            |
#| +   |> filter(                                                   |
#| +     common.funding.x != common.funding.y                       |
#| +   )                                                            |
#| +   #                                                            |
#| +   |> select( 'nctid', 'common.funding.x', 'common.funding.y' ) |
#| +   #                                                            |
#| +   |> (\(x) table(x$common.funding.x, x$common.funding.y) )()   |
#| + )                                                              |
#|                                                                  |
#|            Industry  NIH Other                                   |
#|   Industry        0    1  1394                                   |
#|   NIH             1    0  1174                                   |
#|   Other           7    1     0                                   |
#| >                                                                |
#--------------------------------------------------------------------


# Join dataframes
( df.intersect.orig
  |> inner_join( df.intersect.new, by = 'nctid' )
  #
  |> filter(
    #!( common.funding.x == 'NIH' | common.funding.y == 'NIH' ),
    #!( common.funding.x == 'Other' | common.funding.y == 'Other' ),
    #common.funding.x != 'Other',
    common.funding.y != 'Other',
    common.funding.x != common.funding.y
  )
  #
  |> select( 'nctid', 'common.funding.x', 'common.funding.y' )
  #
)

  #|> filter(
  #  common.funding.x == common.funding.y
  #)

  #|> nrow()

  #|> names() %>% grep('funding', ., value = TRUE)

  #|> summary()

# Compare the the Anderson et al funding
table(
      df.intersect.orig$schema0.funding,
      df.intersect.new$schema1.funding_source_classes
        |>  map_chr( ~ paste(.x, collapse='-') )
) |> addmargins()

# Compare the lead sponsor in the new data with the consolidated sponsor in the
# new data.  This essentially shows which ones have Other as the lead sponsor,
# but non-Other sponsors as collaborators.
table(
      df.intersect.new$schema1.lead_sponsor_funding_source
        |> standardize.jsonl_derived.norm.funding_source()
      ,
      df.intersect.new$schema1.funding_source_classes
        |>  map_chr( ~ paste(.x, collapse='-') )
) |> addmargins()

(
id.intersect.new.both_funding <-
  df.intersect.new
  |> filter(
            'Industry-NIH' == schema1.funding_source_classes |>
                map_chr( ~ paste(.x, collapse='-') )
            )
  |> getElement( 'schema1.nct_id' )
)

table(
      ( df.intersect.orig
        |> filter(
                  schema0.nct_id %in% id.intersect.new.both_funding
                 )
        |> getElement('schema0.funding')
      )
      ,
      df.intersect.new
        |> filter(
                  schema1.nct_id %in% id.intersect.new.both_funding
                 )
        |> getElement('schema1.funding_source_classes')
        |> map_chr( ~ paste(.x, collapse='-') )
)
