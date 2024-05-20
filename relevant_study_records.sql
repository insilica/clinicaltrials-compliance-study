COPY (
    SELECT
        t1.*
    FROM
        read_parquet ('work/all_study_records.parquet') AS t1
        JOIN (
            SELECT
                nctid,
                MAX(version_number) AS max_version
            FROM
                read_parquet ('work/all_study_records.parquet')
            WHERE
                version_date <= '2013-09-27'
            GROUP BY
                nctid
        ) t2 ON t1.nctid = t2.nctid
        AND t1.version_number = t2.max_version
) TO 'work/relevant_study_records.parquet' (COMPRESSION ZSTD);