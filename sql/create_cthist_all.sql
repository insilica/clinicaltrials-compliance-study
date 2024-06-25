INSTALL json;

LOAD json;

COPY (
    SELECT
        *
    FROM
        (
            WITH country AS (
                SELECT
                    list_distinct(
                        studyRecord ->> '$.study.protocolSection.contactsLocationsModule.locations[*].country'
                    ) as location_country,
                    TRY_CAST(change ->> '$.version' AS INTEGER) AS version_number,
                    TRY_CAST(change ->> '$.date' AS DATE) AS version_date,
                    studyRecord ->> '$.study.protocolSection.identificationModule.nctId' AS nct_id,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.oversightModule.oversightHasDmc' AS BOOLEAN
                    ) AS has_dmc,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.oversightModule.isFdaRegulatedDevice' AS BOOLEAN
                    ) AS is_fda_regulated_device,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.oversightModule.isFdaRegulatedDrug' AS BOOLEAN
                    ) AS is_fda_regulated_drug,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.oversightModule.isPpsd' AS BOOLEAN
                    ) AS is_ppsd,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.oversightModule.isUnapprovedDevice' AS BOOLEAN
                    ) AS is_unapproved_device,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.oversightModule.isUsExport' AS BOOLEAN
                    ) AS is_us_export,
                    studyRecord ->> '$.study.protocolSection.statusModule.overallStatus' AS overall_status,
                    list_reduce(
                        (
                            studyRecord -> '$.study.protocolSection.designModule.phases'
                        ) :: VARCHAR [],
                        (acc, val) -> concat(acc, '; ', val)
                    ) AS phase,
                    studyRecord ->> '$.study.protocolSection.statusModule.primaryCompletionDateStruct.date' AS primary_completion_date,
                    -- TODO Partial date type
                    studyRecord ->> '$.study.protocolSection.statusModule.completionDateStruct.date' AS completion_date,
                    -- TODO Partial date type
                    studyRecord ->> '$.study.protocolSection.designModule.studyType' AS study_type,
                    studyRecord ->> '$.study.protocolSection.designModule.designInfo.primaryPurpose' AS primary_purpose,
                    studyRecord ->> '$.study.protocolSection.statusModule.statusVerifiedDate' AS verification_date,
                    -- TODO Partial date type
                    list_distinct(
                        studyRecord ->> '$.study.protocolSection.armsInterventionsModule.interventions[*].type'
                    ) AS intervention_type,
                    studyRecord ->> '$.study.hasResults' as has_results,
                    studyRecord ->> '$.study.protocolSection.sponsorCollaboratorsModule.leadSponsor.class' AS funding_source,
                    studyRecord ->> '$.study.protocolSection.statusModule.resultsFirstPostDateStruct.date' AS results_date,
                    studyRecord ->> '$.study.protocolSection.statusModule.resultsFirstSubmitDate' AS results_rec_date,
                    TRY_CAST(
                        studyRecord -> '$.study.protocolSection.statusModule.dispFirstPostDateStruct.date' AS DATE
                    ) AS disp_date,
                    TRY_CAST(
                        studyRecord -> '$.study.protocolSection.statusModule.dispFirstSubmitDate' AS DATE
                    ) AS disp_submit_date,
                    TRY_CAST(
                        studyRecord -> '$.study.protocolSection.statusModule.dispFirstSubmitQcDate' AS DATE
                    ) AS disp_qc_date,
                FROM
                    read_ndjson_auto (
                        'download/ctgov/historical/NCT*/*.jsonl',
                        maximum_sample_files = 32768,
                        ignore_errors = true
                    )
                WHERE
                    studyRecord IS NOT NULL
                    AND change IS NOT NULL
                    -- AND coalesce(disp_date, disp_submit_date, disp_qc_date) IS NOT NULL
            )
            SELECT
                CASE
                    WHEN list_contains(location_country, 'United States')
                    OR list_contains(location_country, 'Puerto Rico')
                    OR list_contains(location_country, 'American Samoa') THEN true
                    WHEN location_country [1] IS NULL THEN NULL
                    ELSE false
                END AS has_us_facility,
                *
            FROM
                country
        )
) TO 'brick/analysis-20130927/ctgov-studies-all.parquet' (FORMAT PARQUET)