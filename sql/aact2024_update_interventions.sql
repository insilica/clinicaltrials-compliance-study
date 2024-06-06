-- uncomment this if loading file in DuckDB
-- INSTALL postgres;
-- ATTACH 'postgresql://postgres:postgres@localhost:6432/aact_20240430' AS pg (TYPE postgres);

SELECT
	s.nct_id,
	s.study_type,
	s.phase,
	rs.overall_status,
	s.enrollment,
	s.study_first_submitted_date,
	rs.primary_completion_date,
	s.completion_date,
	s.verification_date,
FROM
	
    pg.ctgov.studies s 
	LEFT JOIN pg.ctgov.interventions i ON s.nct_id = i.nct_id
    LEFT JOIN pg.ctgov.calculated_values v on s.nct_id = v.nct_id
    LEFT JOIN pg.ctgov.relevant_studies rs ON s.nct_id = rs.nctid
WHERE
-- 	(
		rs.overall_status != 'Withdrawn'
		AND
		s.nct_id = rs.nctid
		AND
		v.nct_id = rs.nctid
		AND
		(
			rs.primary_completion_date >= '2008-01-01'::DATE
			OR (
				rs.primary_completion_date IS NULL
				AND (
					   completion_date >= '2008-01-01'::DATE
					OR completion_date IS NULL
				)
			)
		)
		AND study_type = 'Interventional'
		AND (
			phase NOT IN ('Phase 1', 'Early Phase 1')
		)
		AND (
			rs.overall_status IN ( 'TERMINATED', 'COMPLETED' )
		)
		AND (
			rs.primary_completion_date < '2012-09-01'::DATE
			OR (
				rs.primary_completion_date IS NULL
				AND (
					   completion_date <  '2012-09-01'::DATE
					OR completion_date IS NULL
				)
			)
		)
		AND (
			rs.primary_completion_date IS NOT NULL
			OR
			completion_date IS NOT NULL
			OR (
				    verification_date >= '2008-01-01'::DATE
				AND verification_date <  '2012-09-01'::DATE
			)
		)
		AND (v.has_us_facility = 'true' OR is_us_export = 'true' OR is_fda_regulated_drug = 'true'
		OR is_fda_regulated_device = 'true'
		OR has_dmc = 'true' OR is_unapproved_device = 'true' OR is_ppsd = 'true')
	-- )
ORDER BY rs.nctid