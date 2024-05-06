#!/bin/bash

set -eu -o pipefail

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 YYYYMMDD_clinical_trials.zip" >&2
	exit 1
fi

if ! [ -f "$1" ]; then
  echo "$1 file not found" >&2
  exit 1
fi

# DEFAULTS
DB_USER="${PGUSER:-postgres}"

# INPUTS
PATH_ZIP="$1"

PATH_ZIP_FILENAME="$(basename "$PATH_ZIP")"
# YYYYMMDD_clinical_trials.zip
PATH_ZIP_FILE_PATTERN='^\d{8}_clinical_trials\.zip$'
if ! echo "$PATH_ZIP_FILENAME" | grep -qP "$PATH_ZIP_FILE_PATTERN"; then
	echo "File name $PATH_ZIP_FILENAME does not match expected pattern ($PATH_ZIP_FILE_PATTERN)" >&2
	exit 1
fi

# Extract out the date part
DB_DATE="$(echo "$PATH_ZIP_FILENAME" | grep -oP '^\d{8}' )"

PATH_EXTRACT=/aact-extract/"$(basename "$PATH_ZIP_FILENAME" .zip)"

if ! [ -d "$PATH_EXTRACT" ]; then
	mkdir -p "$PATH_EXTRACT"
	unzip -o $PATH_ZIP -d "$PATH_EXTRACT"
fi
find "$PATH_EXTRACT"

###

DB_NAME="aact_${DB_DATE}"

echo "Creating database '$DB_NAME'" >&2

## For debugging:
#psql -U ${DB_USER} -c 'DROP DATABASE IF EXISTS '${DB_NAME}

export CREATE_DATABASE="$(cat <<EOF
	SELECT
		'CREATE DATABASE ${DB_NAME}'
	WHERE NOT EXISTS (
		SELECT
		FROM pg_database
		WHERE datname = '${DB_NAME}'
	)\\gexec
EOF
)"

echo "$CREATE_DATABASE" | psql -U ${DB_USER}

###

if [ "$( ls "$PATH_EXTRACT"/postgres*.dmp | wc -l )" != "1" ]; then
	echo "A single Postgres DB dump file must exist in $PATH_EXTRACT" >&2
	exit 1
fi

pg_restore -U ${DB_USER} \
	--verbose \
	--no-acl --no-owner \
	-1 \
	-f - < $PATH_EXTRACT/postgres*.dmp \
	| perl -pe "$(cat <<'EOF'
		# This schema already exists.
		undef $_ if /\QCREATE SCHEMA public;\E/x;
EOF
	)" \
	| psql \
		-U ${DB_USER} \
		-d ${DB_NAME} \
		-v ON_ERROR_STOP=1
