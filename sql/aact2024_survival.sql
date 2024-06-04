SELECT
    id,
    s.nct_id,
    s.primary_completion_date,
    registered_in_calendar_year,
    actual_duration,
    months_to_report_results,
    has_us_facility,
    has_single_facility
FROM
    ctgov.calculated_values v
    JOIN ctgov.studies s ON v.nct_id = s.nct_id
WHERE
    were_results_reported = 'true'
    AND s.primary_completion_date IS NOT NULL
    AND s.primary_completion_date <= '2013-09-27'
    AND registered_in_calendar_year <= '2013';