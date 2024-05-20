SELECT
	-- COUNT(nct_id)
	rs.nctid,
	any_value(study_type),
	any_value(phase),
	any_value(rs.overall_status),
	any_value(enrollment),
	any_value(study_first_submitted_date),
	any_value(rs.primary_completion_date),
	any_value(primary_completion_date_type),
	any_value(completion_date),
	any_value(verification_date),
FROM
	pg.ctgov.studies s, pg.ctgov.relevant_studies rs
WHERE
-- 	(
		rs.overall_status != 'Withdrawn'
		AND
		s.nct_id = rs.nctid
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
	-- )
GROUP BY rs.nctid
ORDER BY rs.nctid