# Note: GNU Makefile
ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

## Requirements:
## docker-compose : <pkg:deb/debian/docker-ce-cli>
## psql           : <pkg:deb/debian/postgresql-client-common>
## xargs
## find
## realpath

### Platform helper
MKDIR_P := mkdir -p
ECHO    := echo

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

.PHONY: help \
	_env-guard \
	run-psql \
	run-psql-csv \
	psql-list-aact-databases

define MESSAGE
Targets for $(MAKE):

## Docker

- docker-build        : build Docker image

- docker-compose-up   : start Docker Compose (in background)
- docker-compose-down : stop Docker Compose

- docker-load-data    : load data from schema dump

## PostgreSQL

- run-psql            : run a given SQL file using `psql`

      make run-psql PGDATABASE=aact_20170105 FILE=/path/to/pg.sql

  Variables:

  - `PGDATABASE`: name of database to connect to
  - `FILE`: path to SQL file

  NOTE: Runs on the host. Requires `psql`.

- psql-list-aact-databases

  Lists AACT database names that have been loaded.

  NOTE: Runs on the host. Requires `psql`.
endef

# Default target
export MESSAGE
help:
	@$(ECHO) "$$MESSAGE"

_env-guard:

env-guard-%: _env-guard
	@if [ -z '${${*}}' ]; then echo 'Environment variable $* not set' && exit 1; fi

.PHONY: \
	docker-build \
	docker-compose-up \
	docker-compose-down \
	docker-load-data

docker-build: Dockerfile
	docker buildx build -t clinicaltrials-aact-db:latest .

docker-compose-up: docker-build \
	env-guard-DOCKER_POSTGRES_DATA_DIR
	@$(MKDIR_P) "${DOCKER_POSTGRES_DATA_DIR}"
	docker compose \
		up -d

docker-compose-down:
	docker compose \
		down

docker-load-data:
	D=./download/aact/db-dump; \
	find $$D -type f -name '*.zip' -print \
		| xargs -I{} realpath --relative-to=$$D {} \
		| xargs -I{} docker compose \
				exec -T db-pg \
					/script/load.sh /aact-data/{}
run-psql: \
	env-guard-FILE \
	env-guard-PGDATABASE
	@if [ -f "${FILE}" ]; then psql < "${FILE}"; fi

run-psql-csv: \
	env-guard-FILE \
	env-guard-PGDATABASE
	@if [ -f "${FILE}" ]; then psql --csv < "${FILE}"; fi

DOLLARDOLLAR:=$$$$

define AACT_DB_SQL
SELECT
	datname
FROM pg_database
WHERE
	datistemplate = false
	AND
	datname LIKE $(DOLLARDOLLAR)aact_%${DOLLARDOLLAR}
;
endef
psql-list-aact-databases:
	psql -c "$${AACT_DB_SQL}"


.PHONY: build-docs
build-docs:
	latexmk -outdir=_build report/code-review.tex
