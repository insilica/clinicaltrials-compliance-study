# DESCRIPTION
#
# 1. Retrieves the NCT IDs from the CTGOV "HLACTs" and from the original paper
#    data.
# 2. Compare their intersection using UpSet diagram.
library(arrow)
library(dotenv)
library(dplyr)
library(readr)
library(vroom)
library(fs)
library(stringr)
library(lubridate)
library(RPostgres)
library(DBI)


library(ggplot2)
library(ComplexUpset)

dotenv::load_dot_env(".env")

## Data from ctgov JSON
query_df <- arrow::read_parquet("brick/analysis-20130927/ctgov-studies-hlact.parquet")

## aact db connection for applying facility and export filters
aact_db <- dbConnect(Postgres(), dbname = "aact_20240430", )

## get the calculated values table
calculated_values <- dbGetQuery(aact_db, "SELECT * FROM ctgov.calculated_values")

# contains some other data on trials' geographic locations
facilities <- dbGetQuery(aact_db, "SELECT * FROM ctgov.facilities")

studies <- dbGetQuery(aact_db, "SELECT * FROM ctgov.studies")

## new run of JSON data from ctgov
fresh_df <- arrow::read_parquet("brick/analysis-20130927/ctgov_fresh.parquet")

## Data from paper results
paper_df <- arrow::read_parquet("brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet")

# number of trials that have only foreign trial locations but have US oversight in the Anderson data
foreign_w_oversight <- paper_df |> filter(us_coderc == 'Foreign only', oversight == 'United States: Food and Drug Administration')

# initial diff of all JSONs and Anderson data
diff0 <- length(setdiff(paper_df$NCT_ID, fresh_df$nct_id))

## apply the overall_status filter
f1 <- fresh_df |> subset(overall_status != "WITHDRAWN")

diff1 <- length(setdiff(paper_df$NCT_ID, f1$nct_id)) # 51

## apply the date filters
f2 <- f1 |>
    dplyr::filter((ym(primary_completion_date) >= lubridate::date("2008-01-01")) |
        (is.na(primary_completion_date))) |>
    dplyr::filter(
        (ym(completion_date) >= lubridate::date("2008-01-01")) |
            (is.na(completion_date))
    )

nrow(f2) # 135037 -- 6/26 now 122732

diff2 <- length(setdiff(paper_df$NCT_ID, f2$nct_id)) # 54 -- 6/26 now 55

## don't remember if we need this...
# f2 |> dplyr::count(primary_completion_date, sort=TRUE)

## apply study type filter
f3 <- f2 |>
    dplyr::filter(study_type == "INTERVENTIONAL")

diff3 <- length(setdiff(paper_df$NCT_ID, f3$nct_id)) # 55 -- 6/26 now 56

## apply phase filter
f4 <- f3 |> dplyr::filter(!(phase %in% c("EARLY_PHASE1", "PHASE1")))


diff4 <- length(setdiff(paper_df$NCT_ID, f4$nct_id)) # 56 -- usw

## apply overall status filter
f5 <- f4 |> dplyr::filter(overall_status %in% c("TERMINATED", "COMPLETED"))
diff5 <- length(setdiff(paper_df$NCT_ID, f5$nct_id)) # 57 -- 58


f6 <- f5 |> dplyr::filter((ym(primary_completion_date) <= lubridate::date("2012-09-01")) |
    (is.na(primary_completion_date)) &
        ym(completion_date) < lubridate::date("2012-09-01") | (is.na(completion_date)))
diff6 <- length(setdiff(paper_df$NCT_ID, f6$nct_id)) # 59 -- 60

## apply upper bound date exclusion
f7 <- f6 |> dplyr::filter((!is.na(primary_completion_date) | !is.na(completion_date)) | (ym(verification_date) >= lubridate::date("2008-01-01") &
    ym(verification_date) < lubridate::date("2012-09-01")))

diff7 <- length(setdiff(paper_df$NCT_ID, f7$nct_id)) # 59 -- 60

## specificity after basic filters applied
reversed_dff <- length(setdiff(f7$nct_id, paper_df$NCT_ID)) # 27011 -- 19078

# intervention type
# f7 |> dplyr::count(intervention_type, sort=TRUE)

num_rows_f7 <- nrow(f7) # 40279 -- 32345

# join with calculated values to bring in oversight criteria
f8 <- dplyr::inner_join(calculated_values, f7, by = c("nct_id" = "nct_id"))

## trying to refine oversight criteria by including
## the country data exposed by this table
join_facilities <- dplyr::inner_join(facilities, calculated_values, by = c("nct_id" = "nct_id"))

## these two joins reflect the SQL written in "sql/create_cthist_hlact.sql"
join_studies <- dplyr::inner_join(join_facilities, studies, by = c("nct_id" = "nct_id"))

## drops the specificity down to 84%, probably not the right thing to examine
# f8 <- group_by(join_studies, nct_id) |> inner_join(f7, by = c("nct_id" = "nct_id")) |> filter(!is.na(has_us_facility))

## find where facility is not false
dplyr::count(f8, (has_us_facility == TRUE | is.na(has_us_facility)))

## find where export is not false
dplyr::count(f8, (is_us_export == TRUE | is.na(is_us_export)))

## is_us_export is always NA
dplyr::group_by(f8, has_us_facility, is_us_export) |> dplyr::count()

diff8 <- length(setdiff(paper_df$NCT_ID, f8$nct_id)) # 59 -- 60
diff8
f9 <- f8 |> dplyr::filter((has_us_facility == TRUE | is.na(has_us_facility)))

length(setdiff(f9$nct_id, foreign_w_oversight$NCT_ID))

setdiff(foreign_w_oversight$NCT_ID, f9$nct_id)

true_negatives<-intersect(f9$nct_id, paper_df$NCT_ID)
false_positives<-setdiff(paper_df$NCT_ID, f9$nct_id)

# sensitivity: 95.13%
sensitivity <- length(true_negatives) / (length(true_negatives) + length(false_positives))

diff9 <- setdiff(paper_df$NCT_ID, f9$nct_id)
ln_diff9 <- length(diff9) # 648 -- 649

length(intersect(diff9, foreign_w_oversight$NCT_ID))

setdiff(foreign_w_oversight$NCT_ID, diff9)

## specificity: 4421
reversed9 <- length(setdiff(f9$nct_id, paper_df$NCT_ID))

## intersection for Upset diagram -- new data
all_ids <- unique(c(paper_df$NCT_ID, f9$nct_id))

upset_df_new <- data.frame(
    ID = all_ids,
    fresh = all_ids %in% f9$nct_id,
    anderson2015 = all_ids %in% paper_df$NCT_ID
)

plot(upset(upset_df_new, c("fresh", "anderson2015"), name = "ID source"))

## intersection for Upset diagram -- old data
upset_df <- data.frame(
    ID = all_ids,
    ctgov_hlact = all_ids %in% query_df$nct_id,
    anderson2015 = all_ids %in% paper_df$NCT_ID
)

## Plot the UpSet diagram

## old data from first run of HLACT filtering
plot(upset(upset_df, c("ctgov_hlact", "anderson2015"), name = "ID source"))
ggsave("nctid-overlap-all.png", width = 12, height = 8)

all_ids <- unique(c(query_df$nct_id, paper_df$NCT_ID))
upset_df <- data.frame(
    ctgov_hlact = all_ids %in% query_df$nct_id,
    anderson2015 = all_ids %in% paper_df$NCT_ID
)
plot(upset(upset_df, c("ctgov_hlact", "anderson2015"), name = "ID source"))
ggsave("hlact-overlap-historical.png", width = 12, height = 8)
