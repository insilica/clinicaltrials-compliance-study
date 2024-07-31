preprocess_data.common.regression <- function(data) {
  # From paper Table 3:
  # Regression models included the following covariates in addition to those
  # listed:
  #   - primary purpose of study,
  #   - enrollment,
  #   - year of study completion,
  #   - study duration,
  #   - number of study groups,
  #   - use of randomized assignment, and
  #   - use of masking.
  split.enrollment <- 32
  split.pc_year <- 2010
  data <- data %>%
    # Define the variables for reporting by a particular time, either by
    mutate(
      # - 12 months or
      rr.results_reported_12mo =
        ( interval(common.primary_completion_date_imputed, common.results_received_date) < months(12) + days(1) ) |>
        replace_na(FALSE),
      # - 5 years.
      rr.results_reported_5yr =
        ( interval(common.primary_completion_date_imputed, common.results_received_date) < years(5) + days(1) ) |>
        replace_na(FALSE),
    ) %>%
    # Phase short names
    mutate(rr.phase =
           fct_recode(common.phase,
                      `1-2` = "Phase 1/Phase 2",
                      `2` = "Phase 2",

                      `2-3` = "Phase 2/Phase 3",
                      `3` = "Phase 3",
                      `4` = "Phase 4",
                      ) |>
           # Turn NA values into "Not applicable" level
           fct_na_value_to_level(level = "Not applicable")
    ) %>%
    mutate(rr.primary_purpose =
           fct_collapse(common.primary_purpose,
                        Other = setdiff(levels(common.primary_purpose),
                                        c("Treatment", "Prevention", "Diagnostic"))) |>
           factor(levels = c('Treatment', 'Prevention', 'Diagnostic', 'Other'))
    ) %>%
    mutate(
           # Impute NA with mean
           enrollment.pre = ifelse(is.na(common.enrollment),
                                   mean(common.enrollment, na.rm = TRUE),
                                   common.enrollment),
           # Replace 0 with a small positive value
           enrollment.pre = ifelse(enrollment.pre == 0, 0.5, enrollment.pre)
    ) |>
    mutate(
           # compare with mntopcom
           rr.study_duration = interval(common.start_date, common.primary_completion_date_imputed) / months(1),
           rr.oversight_is_fda = ifelse(common.oversight == 'United States: Food and Drug Administration',
                                     'Yes', 'No') |>
                             factor( levels = c('Yes', 'No') ) |> relevel( ref = 'Yes' ),
           rr.use_of_randomized_assgn = common.allocation == 'Randomized' & common.number_of_arms > 1,
           rr.masking = case_when(
                                  common.allocation == 'Non-Randomized' ~ "Open",
                                  .default = common.masking
                          ) |> as.factor() |> relevel( ref = 'Open' ),
           rr.log2_enrollment_less_split = ifelse(enrollment.pre <= split.enrollment,
                                                  log2(enrollment.pre),
                                                  0),
           rr.log2_enrollment_more_split = ifelse(enrollment.pre > split.enrollment,
                                                  log2(enrollment.pre),
                                                  0),
           rr.pc_year_increase_pre_split = ifelse(common.pc_year_imputed < split.pc_year,
                                                  common.pc_year_imputed - split.pc_year,
                                                  0),
           rr.pc_year_increase_post_split = ifelse(common.pc_year_imputed >= split.pc_year,
                                                   common.pc_year_imputed - split.pc_year,
                                                   0),
    ) |>
    mutate(
           rr.study_duration.clamp = ifelse(rr.study_duration > 24, 24, rr.study_duration)
    ) |>
    mutate(
      rr.sdur.per_3_months_increase_pre_12  = ifelse(rr.study_duration.clamp <= 12, rr.study_duration.clamp / 3, 12 / 3),
      rr.sdur.per_3_months_increase_post_12 = ifelse(rr.study_duration.clamp > 12, (rr.study_duration.clamp - 12) / 3, 0)
    ) |>
    mutate(
      rr.number_of_arms = case_when(
        common.number_of_arms == 1 ~ "one",
        common.number_of_arms == 2 ~ "two",
        common.number_of_arms >= 3 ~ "three or more"
      ) |> as.factor() |> relevel( ref = "one" )
    ) %>%
    mutate(
      rr.intervention_type  = relevel(common.intervention_type, ref = "Drug"      ),
      rr.funding            = relevel(common.funding,           ref = "NIH"       ),
      rr.phase              = relevel(rr.phase,                 ref = "4"         ),
      rr.primary_purpose    = relevel(rr.primary_purpose,       ref = "Treatment" ),
      rr.overall_status     = relevel(common.overall_status,    ref = "Completed" )
    )

  return(data)
}


##+ mntopcom # weird that this has more exact values?
formula.anderson2015 <-
     rr.results_reported_12mo ~
   ( rr.primary_purpose
   + rr.intervention_type
   + rr.phase
   + rr.oversight_is_fda
   + rr.funding
   + rr.log2_enrollment_less_split + rr.log2_enrollment_more_split
   + rr.overall_status
   + rr.pc_year_increase_pre_split + rr.pc_year_increase_post_split
   + rr.sdur.per_3_months_increase_pre_12 + rr.sdur.per_3_months_increase_post_12
   + rr.number_of_arms
   + rr.use_of_randomized_assgn
   + rr.masking
   )

formula.jsonl_derived <-
     rr.results_reported_12mo ~
   ( rr.primary_purpose
   + rr.intervention_type
   + rr.phase
   # no rr.oversight_is_fda term
   + rr.funding
   + rr.log2_enrollment_less_split + rr.log2_enrollment_more_split
   + rr.overall_status
   + rr.pc_year_increase_pre_split + rr.pc_year_increase_post_split
   + rr.sdur.per_3_months_increase_pre_12 + rr.sdur.per_3_months_increase_post_12
   + rr.number_of_arms
   + rr.use_of_randomized_assgn
   + rr.masking
   )


logistic_regression <- function(data, formula) {
  model <- glm(formula,
               data = data, family = binomial )
  model <- tidy(model, exponentiate = TRUE, conf.int = TRUE)
  return(model)
}

cox_regression <- function(data) {
  model <- coxph(Surv(time_months, event) ~ intervention_type + phase.norm + funding + overall_status, data = data)
  tidy(model, exponentiate = TRUE, conf.int = TRUE)
}


prefixes.rr <- c(
  "rr.primary_purpose", "rr.intervention_type", "rr.phase",
  "rr.oversight_is_fda", "rr.funding", "rr.log2_enrollment_",
  "rr.overall_status", "rr.pc_year_increase_", "rr.sdur.per_3_months_increase_",
  "rr.number_of_arms", "rr.use_of_randomized_assgn", "rr.masking"
)
escaped_prefixes.rr <- map(prefixes.rr, str_escape)
prefix_pattern.rr <- paste(escaped_prefixes.rr, collapse = "|")

compare.model.logistic <- function(model.logistic) {
  paper.regress.s7 <- read.csv('data/anderson2015/table-S7.csv') |>
    mutate(across(term,trimws))

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
      prefix = str_extract(term, prefix_pattern.rr),
      suffix = str_remove(term, prefix_pattern.rr)
  )
  return(or.combined)
}

plot.compare.logistic <- function(or.combined) {
  # Create the box-and-whiskers plot
  fig <- ggplot(or.combined, aes(x = suffix, y = or, color = source)) +
    geom_point(position = position_dodge(width = 0.5)) +
    geom_errorbar(aes(ymin = or.conf.low, ymax = or.conf.high),
                  position = position_dodge(width = 0.5), width = 0.2) +
    facet_wrap(~ prefix, scales = "free", ncol = 3) +
    labs(title = "Comparison of Odds Ratios to Paper Table S7",
         x = "Term",
         y = "Odds Ratio") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  return(fig)
}
