-- syntax: DuckDB SQL (+ templating)
--
-- NAME
--
--   create_cthist_hlact.sql - Create filtered HLACT records
--
-- DESCRIPTION
--
--   Processes the Parquet file of all records generated by
--   `sql/create_cthist_all.sql` and AACT database in order to implement the
--   inclusion criteria for HLACTs filtered within a given time period.
--
--   In particular, retrieves information about facilities and result reporting
--   from the AACT database.
--
-- [% TAGS \[\% \%\] --%% %]
--%% ## See § Templating… in `sql/README.md`.

INSTALL postgres;

-- See `.env.template` for how to set up other connection parameters.
-- Make sure to start the database and source `.env` prior to running this SQL.
-- See `README.md` for how to set up the database.
--%%  FILTER replace('aact_20240430', aact.database.name || 'aact_20240430')
ATTACH 'dbname=aact_20240430' AS pg (TYPE postgres);
--%%  END


CREATE MACRO try_parse_date(date_str) AS (
    try_strptime(date_str, [ '%Y-%m-%d', '%Y-%m' ]) :: DATE
);

COPY (
    SELECT
        *
    FROM
        (
            WITH
            _all AS (
                SELECT
                    *
                FROM
                    read_parquet(
--%%                FILTER replace("brick/[^']+?\.parquet", output.all )
                        'brick/analysis-20130927/ctgov-studies-all.parquet'
--%%                END
                    )
                WHERE
--%%            FILTER replace("2008-01-01", date.start)
--%%                FILTER replace("2012-09-01", date.stop )
                    overall_status != 'WITHDRAWN'
                    AND (
                        try_parse_date(primary_completion_date) :: DATE >= '2008-01-01'
                        OR primary_completion_date IS NULL
                        AND (
                            try_parse_date(completion_date) :: DATE >= '2008-01-01'
                            OR completion_date IS NULL
                        )
                    )
                    AND study_type = 'INTERVENTIONAL'
                    AND phase NOT IN ('EARLY_PHASE1', 'PHASE1')
                    AND overall_status IN ('TERMINATED', 'COMPLETED')
                    AND (
                        try_parse_date(primary_completion_date) :: DATE < '2012-09-01'
                        OR primary_completion_date IS NULL
                        AND (
                            try_parse_date(completion_date) :: DATE < '2012-09-01'
                            OR completion_date IS NULL
                        )
                    )
                    AND (
                        primary_completion_date IS NOT NULL
                        OR completion_date IS NOT NULL
                        OR (
                            try_parse_date(verification_date) :: DATE >= '2008-01-01'
                            AND try_parse_date(verification_date) :: DATE < '2012-09-01'
                        )
                    )
--%%                END
--%%            END
            ),
            aact AS (
                SELECT
                    f.nct_id,
                    any_value(v.has_us_facility) as has_us_facility,
                    any_value(disposition_first_submitted_date) as extension_date2,
                    any_value(f.country) as country,
                    any_value(v.months_to_report_results) as months_to_report_results
                FROM
                    pg.ctgov.calculated_values v
                    JOIN pg.ctgov.facilities f ON v.nct_id = f.nct_id
                    JOIN pg.ctgov.studies s ON v.nct_id = s.nct_id
                WHERE
                    v.has_us_facility IS NOT NULL
                GROUP BY
                    f.nct_id
            )
            SELECT
                *
            FROM
                _all a
                JOIN aact ct ON ct.nct_id = a.nct_id
            WHERE
                (
                    (is_fda_regulated_drug   = true AND primary_purpose = 'INTERVENTIONAL')
                OR  (is_fda_regulated_device = true)
                )
                AND a.has_us_facility = true
                OR ct.has_us_facility = true
        )
--%% FILTER replace("brick/[^']+?\.parquet", output.item('hlact-filtered') )
) TO 'brick/analysis-20130927/ctgov-studies-hlact.parquet' (FORMAT PARQUET)
--%% END
