INSTALL postgres;
ATTACH 'postgresql://postgres:postgres@localhost:6432/aact_20240430' as pg (TYPE postgres);
COPY (
    SELECT *
    FROM (
            with _all as (
                SELECT *
                FROM read_parquet('brick/analysis-20130927/ctgov-studies-all.parquet')
                WHERE overall_status != 'WITHDRAWN'
                    AND (
                        primary_completion_date >= '2008-01-01'
                        OR primary_completion_date IS NULL
                        AND (
                            completion_date >= '2008-01-01'
                            OR completion_date IS NULL
                        )
                    )
                    AND study_type = 'INTERVENTIONAL'
                    AND phase NOT IN ('EARLY_PHASE1', 'PHASE1')
                    AND overall_status IN ('TERMINATED', 'COMPLETED')
                    AND (
                        primary_completion_date <= '2012-09-01'
                        OR primary_completion_date IS NULL
                        AND (
                            completion_date < '2012-09-01'
                            OR completion_date IS NULL
                        )
                    )
                    AND (
                        primary_completion_date IS NOT NULL
                        OR completion_date IS NOT NULL
                        OR (
                            verification_date >= '2008-01-01'
                            AND verification_date < '2012-09-01'
                        )
                    )
            ),
            aact as (
                select f.nct_id,
                    any_value(v.has_us_facility) as has_us_facility,
                    any_value(f.country) as country
                from pg.ctgov.calculated_values v
                    join pg.ctgov.facilities f on v.nct_id = f.nct_id
                where v.has_us_facility IS NOT NULL
                group by f.nct_id
            )
            select *
            from _all a
                join aact ct on ct.nct_id = a.nct_id
            where a.has_us_facility = true
                OR ct.has_us_facility = true
        )
) TO 'brick/analysis-20130927/ctgov-studies-hlact.parquet' (FORMAT PARQUET)