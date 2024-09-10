-- syntax: DuckDB SQL
--
-- NAME
--
--   create_cthist_preproc.sql - Load all JSONL data into a single Parquet file
--
-- DESCRIPTION
--
--   This processes all the versioned historical ClinicalTrials.gov study
--   record JSONL data files and put all valid records in a Parquet file to
--   speed up later processing steps.

INSTALL json;

LOAD json;

COPY (
    SELECT
            change::JSON      AS change,
            studyRecord::JSON AS studyRecord,
    FROM
        read_ndjson_auto(
            'download/ctgov/historical/NCT*/*.jsonl',
            maximum_sample_files = 32768,
            ignore_errors = true
        )
    WHERE
            studyRecord IS NOT NULL
        AND change      IS NOT NULL
) TO 'brick/ctgov/historical/records.parquet' (FORMAT PARQUET, ROW_GROUP_SIZE 100_000)
