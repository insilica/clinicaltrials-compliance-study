COPY (
    SELECT
        COALESCE(primary_completion_date, '1970-01-01') AS primary_completion_date,
        COALESCE(study_start_date, '1970-01-01') AS study_start_date,
        COALESCE(max_age, '') AS max_age,
        COALESCE(version_date, '1970-01-01') AS version_date,
        *
    FROM
        read_parquet ('work/*.parquet', union_by_name = true)
) TO 'all_study_records.parquet' (COMPRESSION ZSTD);