WITH
    i_types AS (
        SELECT
            CASE
                WHEN intervention_type IN ('Radiation', 'Genetic') THEN 'RadGen'
                WHEN intervention_type = 'Drug' THEN 'Drug'
                WHEN intervention_type = 'Device' THEN 'Device'
                WHEN intervention_type = 'Biological' THEN 'Biological'
                WHEN intervention_type = 'Other' THEN 'Other'
            END AS intervention_type
        FROM
            pg.ctgov.interventions i
            INNER JOIN pg.ctgov.studies s ON s.nct_id = i.nct_id
            LEFT JOIN pg.ctgov.calculated_values v on s.nct_id = v.nct_id
            LEFT JOIN pg.ctgov.relevant_studies rs ON s.nct_id = rs.nctid
        WHERE
            (
                intervention_type = 'Drug'
                OR intervention_type = 'Device'
                OR intervention_type = 'Other'
                OR intervention_type = 'Biological'
                OR intervention_type = 'Radiation'
                OR intervention_type = 'Genetic'
            )
            AND rs.overall_status != 'Withdrawn'
            AND (
                rs.primary_completion_date >= '2008-01-01'
                OR (
                    rs.primary_completion_date IS NULL
                    AND (
                        completion_date >= '2008-01-01'
                        OR completion_date IS NULL
                    )
                )
            )
            AND study_type = 'Interventional'
            AND (phase NOT IN ('Phase 1', 'Early Phase 1'))
            AND (rs.overall_status IN ('TERMINATED', 'COMPLETED'))
            AND (
                rs.primary_completion_date < '2012-09-01'
                OR (
                    rs.primary_completion_date IS NULL
                    AND (
                        completion_date < '2012-09-01'
                        OR completion_date IS NULL
                    )
                )
            )
            AND (
                rs.primary_completion_date IS NOT NULL
                OR completion_date IS NOT NULL
                OR (
                    verification_date >= '2008-01-01'
                    AND verification_date < '2012-09-01'
                )
            )
            AND (
                v.has_us_facility = 'true'
                OR is_us_export = 'true'
                OR is_fda_regulated_drug = 'true'
                OR is_fda_regulated_device = 'true'
                OR has_dmc = 'true'
            )
    ),
    type_counts AS (
        SELECT
            intervention_type,
            COUNT(*) AS count
        FROM
            i_types
        GROUP BY
            intervention_type
    ),
    total_counts AS (
        SELECT
            COUNT(*) AS total
        FROM
            i_types
    )
SELECT
    ty.intervention_type,
    ty.count,
    (ty.count::float / tc.total) * 100 AS percentage_frequency
FROM
    type_counts ty,
    total_counts tc
ORDER BY
    percentage_frequency DESC;