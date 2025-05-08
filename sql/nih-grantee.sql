-- syntax: DuckDB SQL

INSTALL json;
LOAD json;

COPY (
	WITH
	sponsors AS (
		SELECT *
		FROM read_parquet('brick/post-rule-to-20240430-by_sponsor/sponsor_compliance_summary.parquet')
	),
	-- Step 1: Explode the sponsors and their NCT IDs
	exploded_sponsors AS (
		SELECT
			"schema1.lead_sponsor_name" AS sponsor_name,
			unnest(list_concat("ncts.compliant","ncts.noncompliant")) AS nct_id
		FROM sponsors
	),
	-- Step 2: Join with the NCT information table
	joined_data AS (
		SELECT
			s.sponsor_name,
			s.nct_id,
			n.study_record ->> '$.protocolSection.sponsorCollaboratorsModule.leadSponsor.class' AS lead_sponsor_funding,
			list_sort(list_distinct(
			    n.study_record ->> '$.protocolSection.sponsorCollaboratorsModule.collaborators[*].class'
			)) AS collaborators_funding
		FROM exploded_sponsors s
		JOIN read_parquet('data/source/clinicaltrials/NCT*_.parquet') n ON s.nct_id = n.nct_id
	),
	-- Step 3: Create NIH grantee flag
	nih_grantee_data AS (
		SELECT
			sponsor_name,
			nct_id,
			(lead_sponsor_funding = 'NIH' OR list_contains(collaborators_funding, 'NIH'))
				AS is_nih_grantee
		FROM joined_data
	),
	-- Step 4: Group by sponsor and aggregate NIH grantee status
	aggregated_sponsors AS (
		SELECT
			sponsor_name,
			bool_or(is_nih_grantee) AS is_nih_grantee
		FROM nih_grantee_data
		GROUP BY sponsor_name
	),
	-- Step 5: Join back with the original sponsor table
	final_result AS (
		SELECT
			s.*,
			a.is_nih_grantee
		FROM sponsors s
		JOIN aggregated_sponsors a ON s."schema1.lead_sponsor_name" = a.sponsor_name
	)
	-- Step 6: Write the final result to a new parquet file
	SELECT * FROM final_result
) TO 'brick/post-rule-to-20240430-by_sponsor-nih-grantees/sponsors_with_nih_status.parquet' (FORMAT PARQUET);
