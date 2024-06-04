-- this query yields
-- +----------------------+---------+------------------------+
-- | "intervention_type"  | "count" | "percentage"           |
-- +----------------------+---------+------------------------+
-- | "Drug"               | 345741  | 41.3267702841132532    |
-- | "Other"              | 109575  | 13.0976102165543274    |
-- | "Device"             | 72124   | 8.6210544308351751     |
-- | "Behavioral"         | 71954   | 8.6007341594519742     |
-- | "Procedure"          | 61492   | 7.3502007523281652     |
-- | "Biological"         | 39345   | 4.7029475151296374     |
-- | "Dietary Supplement" | 24563   | 2.9360401528562532     |
-- | "Radiation"          | 10007   | 1.1961467984217126     |
-- | "Diagnostic Test"    | 7920    | 0.94668558444088773289 |
-- +----------------------+---------+------------------------+

SELECT
    i.intervention_type,
    COUNT(*) AS count,
    (
        COUNT(*) * 100.0 / (
            SELECT
                COUNT(*)
            FROM
                ctgov.interventions
        )
    ) AS percentage
FROM
    ctgov.interventions i
    INNER JOIN ctgov.studies s ON s.nct_id = i.nct_id
WHERE
    s.study_type = 'Interventional'
GROUP BY
    intervention_type
ORDER BY
    percentage DESC;