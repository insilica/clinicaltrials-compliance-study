WITH date_ranges ( start_date, stop_date ) AS (
	VALUES ( '2008-01-01'::DATE,  '2012-09-01'::DATE )
	-- VALUES ( '2020-01-01'::DATE,  '2024-05-01'::DATE )
)
SELECT
	-- COUNT(*)
	nct_id,
	study_type,
	phase,
	overall_status,
	enrollment,
	study_first_submitted_date,
	primary_completion_date,
	primary_completion_date_type,
	completion_date,
	verification_date
FROM
	ctgov.studies, date_ranges
WHERE
	(
		-- nct_id IN ('NCT00000120', 'NCT00000125') AND
		overall_status != 'Withdrawn'
		AND
		(
			primary_completion_date >= date_ranges.start_date
			OR (
				primary_completion_date IS NULL
				AND (
					   completion_date >= date_ranges.start_date
					OR completion_date IS NULL
				)
			)
		)
		AND study_type = 'Interventional'
		AND (
			phase NOT IN ('Phase 1', 'Early Phase 1')
		)
		AND (
			overall_status IN ( 'Terminated', 'Completed' )
		)
		AND (
			primary_completion_date < date_ranges.stop_date
			OR (
				primary_completion_date IS NULL
				AND (
					   completion_date <  date_ranges.stop_date
					OR completion_date IS NULL
				)
			)
		)
		AND (
			primary_completion_date IS NOT NULL
			OR
			completion_date IS NOT NULL
			OR (
				    verification_date >= date_ranges.start_date
				AND verification_date <  date_ranges.stop_date
			)
		)
	)
ORDER BY nct_id
