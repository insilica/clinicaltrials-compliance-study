#!/bin/bash

set -eu

mkdir -p log

JOB_PROCFILE=./log/job-procfile
echo 3 > $JOB_PROCFILE

#export CTHIST_DOWNLOAD_CUTOFF_DATE=2024-04-30

## Do not set `CTHIST_DOWNLOAD_CUTOFF_DATE` so that all record versions are
## downloaded.
unset CTHIST_DOWNLOAD_CUTOFF_DATE

export PGDATABASE_LATEST=aact_20240430

duckdb -noheader -csv -c "$(cat <<EOF
	SELECT NCT_ID
	FROM 'brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet';
EOF
)" \
	| parallel \
		-j"$JOB_PROCFILE" \
		--results log/01_download_cthist_json.anderson2015.par-results.csv \
		--eta --bar \
		-n1 \
		'./stages/fetch-cthist-json.pl {}'

(
	make docker-compose-up >&2;
	[ -r .env ] && . .env;
	export PGDATABASE="$PGDATABASE_LATEST";
	psql --csv -c 'SELECT nct_id FROM ctgov.studies' | awk 'NR > 1'
) \
	| parallel \
		-j"$JOB_PROCFILE" \
		--results log/01_download_cthist_json.postgres_aact.par-results.csv \
		--eta --bar \
		-n1 \
		'./stages/fetch-cthist-json.pl {}'
