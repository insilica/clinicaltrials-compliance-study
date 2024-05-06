SELECT
	*
FROM
	(
		SELECT
			nct_id,
			TO_DATE(verification_month_year, 'Month YYYY') AS verification_date,
			TO_DATE(completion_month_year, 'Month YYYY') AS completion_date,
			TO_DATE(primary_completion_month_year, 'Month YYYY') AS primary_completion_date,
			study_type,
			overall_status,
			phase,
			enrollment
		FROM
			public.studies
	) AS uncomputed
WHERE
	(
		-- nct_id IN ('NCT00000120', 'NCT00000125')AND
		overall_status != 'Withdrawn'
		AND (
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
			-- completion_date IS NULL
			primary_completion_date IS NULL
			AND verification_date < '2012-09-01'::DATE
			AND verification_date > '2008-01-01'::DATE
		)
	)
ORDER BY nct_id
