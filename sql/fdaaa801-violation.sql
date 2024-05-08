-- DESCRIPTION
--
-- List of studies and their result contacts where the
-- `studies.fdaaa801_violation` is true.

SELECT
	studies.nct_id,
	studies.source,
	result_contacts.name
FROM
	ctgov.studies
LEFT JOIN ctgov.result_contacts ON
	studies.nct_id = result_contacts.nct_id
WHERE
	studies.fdaaa801_violation IS TRUE
ORDER BY
	studies.nct_id
