-- syntax: DuckDB SQL (+ templating)
--
-- NAME
--
--   create_cthist_all.sql - Create records before a cut-off date
--
-- DESCRIPTION
--
--   Processes the versioned historical ClinicalTrials.gov study record JSONL
--   data files before a given cut-off date (to represent the date that a given
--   dataset was downloaded).
--
--   Extracts a subset of the study record data needed for further processing
--   as a Parquet file.
--
-- [% TAGS \[\% \%\] --%% %]
--%% ## See § Templating… in `sql/README.md`.
INSTALL json;

LOAD json;

-- funding_source_class_map
--
-- @param `class` VARCHAR
-- @returns VARCHAR
CREATE MACRO funding_source_class_map(class) AS (
       CASE
           WHEN class = 'INDUSTRY' THEN 'Industry'
           WHEN class = 'NIH'      THEN 'NIH'
                                   ELSE 'Other'
       END
);


-- remove_other_if_needed
--
-- Removes 'Other' from a list if there are also values that are not 'Other'.
--
-- @param distinct_classes VARCHAR[]
--        Precondition: Must be distinct (`list_distinct()`).
--
-- @returns VARCHAR[]
CREATE MACRO remove_other_if_needed(distinct_classes) AS (
    CASE
        WHEN list_contains(distinct_classes, 'Other') AND len(distinct_classes) > 1
        THEN list_filter(distinct_classes, x -> x != 'Other')
        ELSE distinct_classes
    END
);

-- consolidate_funding_source_classes
--
-- Creates a list after:
--   * Combining the lead sponsor and collaborator class list,
--   * Applying `funding_source_class_map()` to each element,
--   * Applying `remove_other_if_needed()` to the list.
--
-- @returns VARCHAR[]
CREATE MACRO consolidate_funding_source_classes(
    lead_sponsor_funding_source,
    collaborators_classes) AS (
    remove_other_if_needed(
        list_sort(list_distinct(
                list_transform(
                    list_concat(
                        [lead_sponsor_funding_source],
                        collaborators_classes
                    ),
                    x -> funding_source_class_map(x)
                )
        ))
    )
);


COPY (
    SELECT
        *
    FROM
        (
            WITH
            study_changes AS (
                SELECT
                    CAST(json_extract(change, '$.date')    AS DATE   ) AS change_date,
                    CAST(json_extract(change, '$.version') AS INTEGER) AS change_version,
                    studyRecord->>'$.study.protocolSection.identificationModule.nctId' AS change_nct_id,
                    *
                FROM read_parquet(
                    'brick/ctgov/historical/records.parquet'
                )
                WHERE
--%%                FILTER replace('2013-09-27', date.cutoff)
                    change_date <= '2013-09-27'::DATE -- cut-off date
--%%                END
            ),
            latest_per_file AS (
                SELECT
                    change_nct_id,
                    MAX(change_version) AS max_change_version
                FROM study_changes
                GROUP BY change_nct_id
            ),
            cutoff_study_records AS (
                    SELECT
                        sc.change_date    AS change_date,
                        sc.change_version AS change_version,
                        -- sc.studyRecord->>'$.study.protocolSection.identificationModule.nctId' AS nct_id,
                        sc.change      AS change,
                        sc.studyRecord AS studyRecord
                    FROM study_changes sc
                    JOIN latest_per_file lpf
                        ON  sc.change_nct_id  = lpf.change_nct_id
                        AND sc.change_version = lpf.max_change_version
            ),
            _extract AS (
                SELECT
                    TRY_CAST(change ->> '$.version' AS INTEGER) AS version_number,
                    TRY_CAST(change ->> '$.date'    AS DATE   ) AS version_date,

                    studyRecord ->> '$.study.protocolSection.identificationModule.nctId' AS nct_id,

                    list_sort(list_distinct(
                        studyRecord ->> '$.study.protocolSection.contactsLocationsModule.locations[*].country'
                    )) AS location_country,
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
                    TRY_CAST(
                        studyRecord -> '$.study.protocolSection.designModule.phases' AS VARCHAR[]
                    ) AS phases,
                    studyRecord ->> '$.study.protocolSection.statusModule.startDateStruct.date' AS start_date,
                    -- TODO Partial date type
                    studyRecord ->> '$.study.protocolSection.statusModule.primaryCompletionDateStruct.date' AS primary_completion_date,
                    -- TODO Partial date type
                    studyRecord ->> '$.study.protocolSection.statusModule.completionDateStruct.date' AS completion_date,
                    -- TODO Partial date type
                    studyRecord ->> '$.study.protocolSection.designModule.studyType' AS study_type,
                    studyRecord ->> '$.study.protocolSection.designModule.designInfo.primaryPurpose' AS primary_purpose,
                    studyRecord ->> '$.study.protocolSection.designModule.designInfo.allocation' AS allocation,
                    studyRecord ->> '$.study.protocolSection.designModule.designInfo.maskingInfo.masking' AS masking,
                    TRY_CAST(
                        studyRecord ->> '$.study.protocolSection.designModule.enrollmentInfo.count' AS INTEGER
                    ) AS enrollment,
                    studyRecord ->> '$.study.protocolSection.statusModule.statusVerifiedDate' AS verification_date,
                    -- TODO Partial date type
                    list_sort(list_distinct(
                        studyRecord ->> '$.study.protocolSection.armsInterventionsModule.interventions[*].type'
                    )) AS intervention_type,
                    len(
                        studyRecord ->> '$.study.protocolSection.armsInterventionsModule.armGroups[*]'
                    ) AS number_of_arm_groups,
                    len(
                        studyRecord ->> '$.study.protocolSection.armsInterventionsModule.interventions[*]'
                    ) AS number_of_interventions,
                    studyRecord ->> '$.study.hasResults' as has_results,
                    studyRecord ->> '$.study.protocolSection.sponsorCollaboratorsModule.leadSponsor.class' AS lead_sponsor_funding_source,
                    studyRecord ->> '$.study.protocolSection.sponsorCollaboratorsModule.leadSponsor.name' AS lead_sponsor_name,
                    list_sort(list_distinct(
                        studyRecord ->> '$.study.protocolSection.sponsorCollaboratorsModule.collaborators[*].class'
                    )) AS collaborators_classes,
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
                        cutoff_study_records
            )
            SELECT
                *,
                -- `list_distinct()` ensures that the list `location_country`
                -- does not contain `NULL` elements (but can still be `NULL` or
                -- `[]` itself).
                list_has_any(
                    NULLIF(list_distinct(location_country), []),
                    [
                        'United States',
                        'Puerto Rico',
                        'American Samoa',
                    ]
                ) AS has_us_facility,
                list_reduce(
                    phases,
                    (acc, val) -> concat(acc, '; ', val)
                ) AS phase,
                consolidate_funding_source_classes(
                    lead_sponsor_funding_source,
                    collaborators_classes
                ) AS funding_source_classes,
            FROM
                _extract
        )
--%% FILTER replace("brick/[^']+?\.parquet", output.all)
) TO 'brick/analysis-20130927/ctgov-studies-all.parquet' (FORMAT PARQUET)
--%% END
