SELECT
	nct_id,
	study_first_submitted_date,
	study_first_posted_date_type,
	verification_date,
	completion_date,
	primary_completion_month_year,
	primary_completion_date_type,
	primary_completion_date,
	study_type,
	overall_status,
	phase,
	enrollment
FROM
	ctgov.studies
WHERE
	(
		overall_status != 'Withdrawn'
		AND
		(
			primary_completion_date >= '2008-01-01'::DATE
			OR (
				primary_completion_date IS NULL
				AND (
					completion_date >= '2008-01-01'::DATE
					OR completion_date IS NULL
				)
			)
		)
		AND study_type = 'Interventional'
		AND (
			phase != 'Phase 1'
			OR phase != 'Early Phase 1'
		)
		AND (
			overall_status = 'Terminated'
			OR overall_status = 'Completed'
		)
		AND (
			primary_completion_date < '2012-09-01'::DATE
			OR primary_completion_date IS NULL
		)
		AND (
			primary_completion_date IS NULL
			AND verification_date < '2012-09-01'::DATE
			AND verification_date > '2008-01-01'::DATE
		)
	)
ORDER BY nct_id
