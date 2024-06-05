#!/bin/bash

set -eu

## Find missing data relative to anderson2015
duckdb -c "$(cat <<'EOF'
SELECT
	NCT_ID
FROM 'brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet'
WHERE
	NCT_ID NOT IN (
		SELECT
			DISTINCT studyRecord->>'$.study.protocolSection.identificationModule.nctId' AS nctid
		FROM read_ndjson_auto('download/ctgov/historical/**/*.jsonl')
		WHERE studyRecord IS NOT NULL
	)
;
EOF
)"

## These are also the ones that failed due to not being able to download the versions
## e.g.,
##
## "Failed to download https://clinicaltrials.gov/api/int/studies/NCT00000141/history: Not Found"
duckdb -csv -c "$(cat <<'EOF'
SELECT
	V1, ExitVal, Stderr
FROM 'log/01_download_cthist_json.anderson2015.par-results.csv'
WHERE
	ExitVal != 0
ORDER BY V1
;
EOF
)"
