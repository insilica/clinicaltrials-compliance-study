INSTALL postgres;

-- See `.env.template` for how to set up other connection parameters.
-- Make sure to source `.env` prior to running this SQL.
ATTACH 'dbname=aact_20240430' AS pg (TYPE postgres);

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
                        'brick/analysis-20130927/ctgov-studies-all.parquet'
                    )
                WHERE
                    overall_status != 'WITHDRAWN'
                    AND (
                        strptime(primary_completion_date, '%Y-%m') :: DATE >= '2008-01-01'
                        OR primary_completion_date IS NULL
                        AND (
                            strptime(completion_date, '%Y-%m') :: DATE >= '2008-01-01'
                            OR completion_date IS NULL
                        )
                    )
                    AND study_type = 'INTERVENTIONAL'
                    AND phase NOT IN ('EARLY_PHASE1', 'PHASE1')
                    AND overall_status IN ('TERMINATED', 'COMPLETED')
                    AND (
                        strptime(primary_completion_date, '%Y-%m') :: DATE <= '2012-09-01'
                        OR primary_completion_date IS NULL
                        AND (
                            strptime(completion_date, '%Y-%m') :: DATE < '2012-09-01'
                            OR completion_date IS NULL
                        )
                    )
                    AND (
                        primary_completion_date IS NOT NULL
                        OR completion_date IS NOT NULL
                        OR (
                            strptime(verification_date, '%Y-%m') :: DATE >= '2008-01-01'
                            AND strptime(verification_date, '%Y-%m') :: DATE < '2012-09-01'
                        )
                    )
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
) TO 'brick/analysis-20130927/ctgov-studies-hlact.parquet' (FORMAT PARQUET)
