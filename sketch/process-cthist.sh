#!/bin/sh

set -eu

CURDIR=`dirname "$0"`
cd $CURDIR/..

. .env

## Create work/NCT*.parquet
R ./stages/01_download_cts.R

## Create work/empty.parquet
duckdb < ./sql/create_empty.sql

## Create work/all_study_records.parquet
python3 ./stages/process_parquet.py

## Create work/relevant_study_records.parquet
duckdb < ./sql/relevant_study_records.sql

## Load work/relevant_study_records.parquet
## into PostgreSQL table `ctgov.relevant_studies`
duckdb < ./sql/create_pg_relevant.sql

## Apply criteria
duckdb -csv < sql/aact2024_update.sql > relevant-studies.csv
wc -l relevant-studies.csv
