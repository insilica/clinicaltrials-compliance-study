if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( purrr, dplyr, stringr, ggplot2 )

source('analysis/lib-anderson2015.R')

### INPUT
hlact.studies <- arrow::read_parquet('brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet') |>
  tibble()
print(hlact.studies)#DEBUG
# Censoring date
censor_date <- as.Date("2013-09-27")

paper.regress.s7 <- read.csv('data/anderson2015/table-S7.csv') |>
  mutate(across(term,trimws))

### PREPROCESS
hlact.studies <- preprocess_data(hlact.studies, censor_date)

### REGRESSION MODELS
model.logistic <- logistic_regression(hlact.studies)
model.logistic |> print(n = 50 ); NA

prefixes <- c(
  "rr.primary_purpose", "rr.intervention_type", "rr.phase",
  "rr.oversight_is_fda", "rr.funding", "rr.log2_enrollment_",
  "rr.overall_statusc", "rr.pc_year_increase_", "rr.sdur.per_3_months_increase_",
  "rr.number_of_arms", "rr.use_of_randomized_assgn", "rr.masking"
)
escaped_prefixes <- map(prefixes, str_escape)
prefix_pattern <- paste(escaped_prefixes, collapse = "|")

or.combined <- bind_rows(
        model.logistic |>
          rename(
                 or = estimate,
                 or.conf.low = conf.low,
                 or.conf.high = conf.high
          ) |>
          filter( term != '(Intercept)' ) |>
          select( term, or, or.conf.low, or.conf.high ) |>
          mutate( source = 'Model' ),
        paper.regress.s7 |>
          select( term, or, or.conf.low, or.conf.high ) |>
          mutate( source = 'Paper' ),
) %>%
mutate(
    prefix = str_extract(term, prefix_pattern),
    suffix = str_remove(term, prefix_pattern)
)
or.combined |> arrange(term) |> print(n = 100)


# Step 4: Create the box-and-whiskers plot
ggplot(or.combined, aes(x = suffix, y = or, color = source)) +
  geom_point(position = position_dodge(width = 0.5)) +
  geom_errorbar(aes(ymin = or.conf.low, ymax = or.conf.high),
                position = position_dodge(width = 0.5), width = 0.2) +
  facet_wrap(~ prefix, scales = "free", ncol = 3) +
  labs(title = "Comparison of Odds Ratios to Paper Table S7",
       x = "Term",
       y = "Odds Ratio") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("figtab/anderson2015/compare.table_s7.or.png", width = 12, height = 8)
