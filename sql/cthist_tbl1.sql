-- ATTACH 'postgresql://postgres:postgres@localhost:6432/aact_20240430' as pg (TYPE postgres);
with _all as (
    SELECT *
    FROM read_parquet('brick/ctgov/processed_with_results.parquet')
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
    select *
    from pg.ctgov.calculated_values v
        join pg.ctgov.facilities f on v.nct_id = f.nct_id
    where v.has_us_facility IS NOT NULL
        and v.has_single_facility = false
)
select ct.has_us_facility as ct_usa,
    ct.country,
    a.has_us_facility as a_usa,
    a.location_country
from _all a
    join aact ct on ct.nct_id = a.nct_id,
    where ct.has_us_facility <> a.has_us_facility