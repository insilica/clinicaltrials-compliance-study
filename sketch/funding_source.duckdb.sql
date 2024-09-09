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
	stat_count_of_distinct_class_lists
	-- stat_count_of_length_of_distinct_class_lists
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
