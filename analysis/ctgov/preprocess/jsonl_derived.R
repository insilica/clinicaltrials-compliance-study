standardize.jsonl_derived <- function(df) {
  df |>
    add_prefix('schema1.') |>
    standardize.jsonl_derived.type()  |>
    standardize.jsonl_derived.dates() |>
    standardize.jsonl_derived.norm()  |>
    mutate(
           common.enrollment = schema1.enrollment,

           # Create a column of NA because oversight is not in this schema
           common.oversight  = factor(NA,
                                      levels = c(
                                                 "No United States Oversight Authority",
                                                 "United States: Food and Drug Administration",
                                                 "United States: Non-FDA Only"
                                                 )
                                      ),
    )
}

standardize.jsonl_derived.type <- function(data) {
  data |>
    mutate(
      # These are all factor variables.
      across(c(schema1.phase, schema1.overall_status,
               schema1.lead_sponsor_funding_source,
               schema1.primary_purpose,
               schema1.allocation, schema1.masking), as.factor),
    ) |>
    mutate(schema1.primary_purpose =
           fct_expand(schema1.primary_purpose
                     ,           "BASIC_SCIENCE"
                     ,              "DIAGNOSTIC"
                     ,                     "ECT"
                     ,"HEALTH_SERVICES_RESEARCH"
                     ,              "PREVENTION"
                     ,               "SCREENING"
                     ,         "SUPPORTIVE_CARE"
                     ,               "TREATMENT"
           )
    )
}

standardize.jsonl_derived.dates <- function(data) {
  data <- data |>
    # Create the primary completion date based on the given priority
    mutate(common.primary_completion_date_imputed = coalesce(
      create_date_partial(schema1.primary_completion_date),
      create_date_partial(schema1.completion_date),
      create_date_partial(schema1.verification_date)
    ) |> as.Date() ) |>
    # Convert results_received_date to Date object
    mutate(common.results_received_date =
           create_date_partial(schema1.results_rec_date)
    ) |>
    mutate(
           common.start_date = create_date_partial(schema1.start_date),
    )
  return(data)
}

standardize.jsonl_derived.norm <- function(data) {
  data <- data %>%
    # Normalize phases
    mutate(common.phase =
           # Rename phases
           fct_recode(schema1.phase,
                      `Phase 1/Phase 2` = "PHASE1; PHASE2",
                      `Phase 2/Phase 3` = "PHASE2; PHASE3",
                      `Phase 2`         = "PHASE2",
                      `Phase 3`         = "PHASE3",
                      `Phase 4`         = "PHASE4",
                      NULL              = "NA",
           )
    ) |>
    mutate(common.primary_purpose =
           fct_recode(schema1.primary_purpose
                     ,                  `Basic Science` =            "BASIC_SCIENCE"
                     ,                     `Diagnostic` =               "DIAGNOSTIC"
                     ,`Educational/Counseling/Training` =                      "ECT"
                     ,       `Health Services Research` = "HEALTH_SERVICES_RESEARCH"
                     ,                     `Prevention` =               "PREVENTION"
                     ,                      `Screening` =                "SCREENING"
                     ,                `Supportive Care` =          "SUPPORTIVE_CARE"
                     ,                      `Treatment` =                "TREATMENT"
            )
    ) |>
    mutate(common.allocation =
           fct_recode(schema1.allocation
                     ,`NA:Single Study` =             "NA"
                     , `Non-Randomized` = "NON_RANDOMIZED"
                     ,     `Randomized` =     "RANDOMIZED"
            )
    ) |>
    mutate(
           # Use arm groups if it exists, otherwise interventions.
           common.number_of_arms =
             ifelse(schema1.number_of_arm_groups != 0,
                    schema1.number_of_arm_groups,
                    schema1.number_of_interventions )
    ) |>
    mutate(common.masking =
           fct_recode(schema1.masking
                     ,`Open`         = "NONE"

                     ,`Single Blind` = "SINGLE"

                     ,`Double Blind` = "DOUBLE"
                     ,`Double Blind` = "TRIPLE"
                     ,`Double Blind` = "QUADRUPLE"
           )
    ) |>
    mutate(common.intervention_type =
           map_chr(schema1.intervention_type,
                   ~ case_when(
                               'DEVICE'     %in% .x ~ "Device",
                               'BIOLOGICAL' %in% .x ~ "Biological",
                               'DRUG'       %in% .x ~ "Drug",
                               .default             = "Other"
                   )
           ) %>%
           # match factor level order used in paper
           factor(levels = c("Device", "Biological", "Drug", "Other"))
    ) |>
    mutate(common.funding =
           case_when(
               schema1.lead_sponsor_funding_source == "INDUSTRY" ~ "Industry",
               schema1.lead_sponsor_funding_source == "NIH"      ~ "NIH",
               .default                             = "Other"
           ) |> factor()
    ) |>
    mutate(common.overall_status =
           fct_recode(schema1.overall_status
                      , `Completed` =  "COMPLETED"
                      ,`Terminated` = "TERMINATED"
           )
    )

  return(data)
}
