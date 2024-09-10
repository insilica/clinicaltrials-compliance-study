-- SQL dialect: DuckDB

-- funding_source_class_map
--
-- @param `class` VARCHAR
-- @returns VARCHAR
CREATE MACRO funding_source_class_map(class) AS (
       CASE
           WHEN class = 'INDUSTRY' THEN 'Industry'
           WHEN class = 'NIH'      THEN 'NIH'
                                   ELSE 'Other'
       END
);


-- remove_other_if_needed
--
-- Removes 'Other' from a list if there are also values that are not 'Other'.
--
-- @param distinct_classes VARCHAR[]
--        Precondition: Must be distinct (`list_distinct()`).
--
-- @returns VARCHAR[]
CREATE MACRO remove_other_if_needed(distinct_classes) AS (
    CASE
        WHEN list_contains(distinct_classes, 'Other') AND len(distinct_classes) > 1
        THEN list_filter(distinct_classes, x -> x != 'Other')
        ELSE distinct_classes
    END
);

-- normalize_funding_source
--
-- @param lead_sponsor_funding_source VARCHAR
-- @param collaborators_classes VARCHAR[]
--
-- Creates a single funding source based on the definition from the
-- data dictionary:
--
-- > Derived from Sponsor and Collaborator information. If Sponsor is from NIH,
-- > or at least one collaborator is from NIH with no Industry sponsor then
-- > funding=NIH. Otherwise if Sponsor is from Industry or at least one
-- > collaborator is from Industry then funding=Industry. Studies with no
-- > Industry or NIH Sponsor or collaborators are assigned funding=Other.
--
-- @returns VARCHAR
CREATE MACRO normalize_funding_source(
    lead_sponsor_funding_source,
    collaborators_classes) AS (
    CASE
        WHEN
        --  If lead sponsor is from 'NIH'
            lead_sponsor_funding_source = 'NIH'
        --  Or if if the collaborators contains 'NIH',
        --  but not 'INDUSTRY'.
             OR (
                         list_contains(collaborators_classes, 'NIH')
                 AND NOT list_contains(collaborators_classes, 'INDUSTRY')
             )
        THEN 'NIH'

        WHEN
        --      If the lead sponsor is from 'INDUSTRY'
                lead_sponsor_funding_source = 'INDUSTRY'
        --      Or any of the collaborators are from 'INDUSTRY'
             OR list_contains(collaborators_classes, 'INDUSTRY')
        THEN 'Industry'

        -- Default to Other if neither 'NIH' nor 'INDUSTRY' are found
        ELSE 'Other'
    END
);

WITH
mapped_only_lead_sponsor_class AS (
	SELECT
		funding_source_class_map(lead_sponsor_funding_source)
			AS class
	FROM 'brick/analysis-20130927/ctgov-studies-hlact.parquet'
),
mapped_classes AS (
	SELECT
	list_sort(list_distinct(
		list_transform(
			list_concat(
				[lead_sponsor_funding_source],
				collaborators_classes
			),
			---- Apply mapping
			---- #############
			x -> funding_source_class_map(x)
			---- No mapping
			---- ##########
			-- x -> x
		)
	)) AS classes
	FROM 'brick/analysis-20130927/ctgov-studies-hlact.parquet'
),
mapped_classes_collapse_other AS (
	SELECT
		remove_other_if_needed(classes)
			AS classes
	FROM mapped_classes
),
mapped_classes_norm AS (
	SELECT
		normalize_funding_source(
				lead_sponsor_funding_source,
				collaborators_classes
		) AS norm_class
	FROM 'brick/analysis-20130927/ctgov-studies-hlact.parquet'
),
stat_count_of_lead_sponsor_class AS (
	SELECT
		COUNT(class) AS class_count,
		list(DISTINCT class) AS class
	FROM
		mapped_only_lead_sponsor_class
	GROUP BY class
	ORDER BY class_count
),
stat_count_of_distinct_class_lists AS (
	SELECT
		COUNT(classes) AS classes_count,
		list(DISTINCT classes) AS classes
	FROM
		-- mapped_classes
		mapped_classes_collapse_other
	GROUP BY classes
	ORDER BY classes_count
),
stat_count_of_norm_classes AS (
	SELECT
		COUNT(norm_class) AS norm_class_count,
		norm_class
	FROM
		mapped_classes_norm
	GROUP BY norm_class
	ORDER BY norm_class_count
),
stat_count_of_length_of_distinct_class_lists AS (
	SELECT
		len(distinct_classes)
			AS class_count,
		list_sort(list(distinct_classes))
	FROM (
		SELECT
		DISTINCT classes AS distinct_classes
		FROM
			mapped_classes
	)
	GROUP BY class_count
	ORDER BY class_count
)
SELECT *
FROM
	-- stat_count_of_lead_sponsor_class
	-- stat_count_of_distinct_class_lists
	-- stat_count_of_length_of_distinct_class_lists
	stat_count_of_norm_classes
;


-- ------------------------------------------
-- |   SELECT *                             |
-- |   FROM                                 |
-- |       stat_count_of_lead_sponsor_class |
-- |   ;                                    |
-- | ┌─────────────┬────────────┐           |
-- | │ class_count │   class    │           |
-- | │    int64    │ varchar[]  │           |
-- | ├─────────────┼────────────┤           |
-- | │         748 │ [NIH]      │           |
-- | │        6130 │ [Industry] │           |
-- | │        7795 │ [Other]    │           |
-- | └─────────────┴────────────┘           |
-- ------------------------------------------

-- ----------------------------------------------
-- |   SELECT *                                 |
-- |   FROM                                     |
-- |       stat_count_of_distinct_class_lists   |
-- |   ;                                        |
-- | ┌───────────────┬────────────────────────┐ |
-- | │ classes_count │ list(DISTINCT classes) │ |
-- | │     int64     │      varchar[][]       │ |
-- | ├───────────────┼────────────────────────┤ |
-- | │           183 │ [[Industry, NIH]]      │ |
-- | │          2604 │ [[NIH]]                │ |
-- | │          4178 │ [[Other]]              │ |
-- | │          7708 │ [[Industry]]           │ |
-- | └───────────────┴────────────────────────┘ |
-- ----------------------------------------------

-- -------------------------------------
-- | ┌──────────────────┬────────────┐ |
-- | │ norm_class_count │ norm_class │ |
-- | │      int64       │  varchar   │ |
-- | ├──────────────────┼────────────┤ |
-- | │             2668 │ NIH        │ |
-- | │             4178 │ Other      │ |
-- | │             7827 │ Industry   │ |
-- | └──────────────────┴────────────┘ |
-- -------------------------------------
