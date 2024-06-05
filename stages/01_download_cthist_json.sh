#!/bin/sh

set -eu

mkdir -p log

export CTHIST_DOWNLOAD_CUTOFF_DATE=2013-09-27
duckdb -noheader -csv -c "$(cat <<EOF
	SELECT NCT_ID
	FROM 'brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet';
EOF
)" \
	| parallel \
		-j1 \
		--results log/01_download_cthist_json.anderson2015.par-results.csv \
		--eta --bar \
		-n1 \
		'./stages/fetch-cthist-json.pl {}'
