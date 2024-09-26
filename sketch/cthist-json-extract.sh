#!/bin/bash

# Spec:
# <url:https://clinicaltrials.gov/api/oas/v2>
# <url:https://clinicaltrials.gov/data-api/api#get-/studies>

## NOTE
##
## This assumes that the JSON Lines files only contains the last study before
## the cutoff date.

### These are useful for provenance.
#-------------------------+----------------------------------------------------------------
# version_number          | .change.version
# version_date            | .change.date

### These are needed for the filtering criteria.
#-------------------------+----------------------------------------------------------------
# nct_id                  | .study.protocolSection.identificationModule.nctId
# has_dmc                 | .study.protocolSection.oversightModule.oversightHasDmc
# has_us_facility         | TODO
# is_fda_regulated_device | .study.protocolSection.oversightModule.isFdaRegulatedDevice
# is_fda_regulated_drug   | .study.protocolSection.oversightModule.isFdaRegulatedDrug
# is_ppsd                 | .study.protocolSection.oversightModule.isPpsd
# is_unapproved_device    | .study.protocolSection.oversightModule.isUnapprovedDevice
# is_us_export            | .study.protocolSection.oversightModule.isUsExport
# overall_status          | .study.protocolSection.statusModule.overallStatus
# phase                   | .study.protocolSection.designModule.phases                               | ∈ { [ "PHASE3" ] }
# primary_completion_date | .study.protocolSection.statusModule.primaryCompletionDateStruct.date
# completion_date         | .study.protocolSection.statusModule.completionDateStruct.date
# study_type              | .study.protocolSection.designModule.studyType
# primary_purpose         | .study.protocolSection.designModule.designInfo.primaryPurpose            | ∈ { DEVICE_FEASIBILITY, ... }
# verification_date       | .study.protocolSection.statusModule.statusVerifiedDate
# intervention_type       | .study.protocolSection.armsInterventionsModule.interventions|map(.type)  | ∈ { DRUG, ... }

### These are not needed.
#-------------------------+----------------------------------------------------------------
# enrollment              | .study.protocolSection.designModule.enrollmentInfo.count
# enrollment_type         | .study.protocolSection.designModule.enrollmentInfo.type
# study_start_date        | .study.protocolSection.statusModule.startDateStruct.date
# fdaaa801Violation       | .study.protocolSection.oversightModule.fdaaa801Violation


duckdb -c "$(cat <<'EOF'
	(
		SELECT
			   TRY_CAST(change->>'$.version' AS INTEGER)                                                               AS version_number          ,
			   TRY_CAST(change->>'$.date' AS DATE)                                                                     AS version_date            ,

			   studyRecord->>'$.study.protocolSection.identificationModule.nctId'                                      AS nct_id                  ,
			   TRY_CAST(studyRecord->>'$.study.protocolSection.oversightModule.oversightHasDmc' AS BOOLEAN)            AS has_dmc                 ,
			   list_distinct(
    		 studyRecord->>'$.study.protocolSection.contactsLocationsModule.locations[*].country'
  			   ) 																									   AS location_countries,
			   TRY_CAST(studyRecord->>'$.study.protocolSection.oversightModule.isFdaRegulatedDevice' AS BOOLEAN)       AS is_fda_regulated_device ,
			   TRY_CAST(studyRecord->>'$.study.protocolSection.oversightModule.isFdaRegulatedDrug' AS BOOLEAN)         AS is_fda_regulated_drug   ,
			   TRY_CAST(studyRecord->>'$.study.protocolSection.oversightModule.isPpsd' AS BOOLEAN)                     AS is_ppsd                 ,
			   TRY_CAST(studyRecord->>'$.study.protocolSection.oversightModule.isUnapprovedDevice' AS BOOLEAN)         AS is_unapproved_device    ,
			   TRY_CAST(studyRecord->>'$.study.protocolSection.oversightModule.isUsExport' AS BOOLEAN)                 AS is_us_export            ,
			   studyRecord->>'$.study.protocolSection.statusModule.overallStatus'                                      AS overall_status          ,
			   list_reduce((studyRecord->'$.study.protocolSection.designModule.phases')::VARCHAR[], (acc,val) -> concat(acc, ', ', val))	                               AS phase                   ,
			   studyRecord->>'$.study.protocolSection.statusModule.primaryCompletionDateStruct.date'                   AS primary_completion_date , -- TODO Partial date type
			   studyRecord->>'$.study.protocolSection.statusModule.completionDateStruct.date'                          AS completion_date         , -- TODO Partial date type
			   studyRecord->>'$.study.protocolSection.designModule.studyType'                                          AS study_type              ,
			   studyRecord->>'$.study.protocolSection.designModule.designInfo.primaryPurpose'                          AS primary_purpose         ,
			   studyRecord->>'$.study.protocolSection.statusModule.statusVerifiedDate'                                 AS verification_date       , -- TODO Partial date type
			   list_distinct(studyRecord->>'$.study.protocolSection.armsInterventionsModule.interventions[*].type')    AS intervention_type       --
		FROM read_ndjson_auto('download/ctgov/historical/NCT*/*.jsonl', maximum_sample_files = 32768, ignore_errors = true )
		WHERE
		       studyRecord IS NOT NULL
			   AND change IS NOT NULL
	)
;
EOF
)"
