INSTALL postgres;

-- See `.env.template` for how to set up other connection parameters.
-- Make sure to source `.env` prior to running this SQL.
ATTACH 'dbname=aact_20240430' AS pg (TYPE postgres);

COPY (
    SELECT
        *
    FROM
        (
            with _all as (
                SELECT
                    *
                FROM
                    read_parquet(
                        'brick/analysis-20130927/ctgov-studies-all.parquet'
                    )
                WHERE
                    overall_status != 'WITHDRAWN'
                    AND (
                        strptime(primary_completion_date, '%Y-%m') :: date >= '2008-01-01'
                        OR primary_completion_date IS NULL
                        AND (
                            strptime(completion_date, '%Y-%m') :: date >= '2008-01-01'
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
                                strptime(verification_date, '%Y-%m') :: date >= '2008-01-01'
                                AND strptime(verification_date, '%Y-%m') :: date < '2012-09-01'
                            )
                        )
                    ),
                    aact as (
                        select
                            f.nct_id,
                            any_value(v.has_us_facility) as has_us_facility,
                            any_value(disposition_first_submitted_date) as extension_date2,
                            any_value(f.country) as country,
                            any_value(v.months_to_report_results) as months_to_report_results
                        from
                            pg.ctgov.calculated_values v
                            join pg.ctgov.facilities f on v.nct_id = f.nct_id
                            join pg.ctgov.studies s on v.nct_id = s.nct_id
                        where
                            v.has_us_facility IS NOT NULL
                        group by
                            f.nct_id
                    )
                select
                    *
                from
                    _all a
                    join aact ct on ct.nct_id = a.nct_id
                where
                    ((is_fda_regulated_drug = true AND primary_purpose = 'INTERVENTIONAL') OR is_fda_regulated_device = true)
                    AND a.has_us_facility = true
                    OR ct.has_us_facility = true
            )
        ) TO 'brick/analysis-20130927/ctgov-studies-hlact.parquet' (FORMAT PARQUET)