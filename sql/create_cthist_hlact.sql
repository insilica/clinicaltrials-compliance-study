-- syntax: DuckDB SQL (+ templating)
--
-- NAME
--
--   create_cthist_hlact.sql - Create filtered HLACT records
--
-- DESCRIPTION
--
--   Processes the Parquet file of all records generated by
--   `sql/create_cthist_all.sql` and AACT database in order to implement the
--   inclusion criteria for HLACTs filtered within a given time period.
--
--   In particular, retrieves information about facilities and result reporting
--   from the AACT database.
--
-- [% TAGS \[\% \%\] --%% %]
--%% ## See § Templating… in `sql/README.md`.

INSTALL postgres;

-- See `.env.template` for how to set up other connection parameters.
-- Make sure to start the database and source `.env` prior to running this SQL.
-- See `README.md` for how to set up the database.
--%%  FILTER replace('aact_20240430', aact.database.name || 'aact_20240430')
ATTACH 'dbname=aact_20240430' AS pg (TYPE postgres);
--%%  END


CREATE MACRO try_parse_date(date_str) AS (
    try_strptime(date_str, [ '%Y-%m-%d', '%Y-%m' ]) :: DATE
);

--%% UNLESS query.do_select_count # {{{
COPY (
    SELECT
        *
--%% ELSE
    SELECT
        '\[\% query.count_key_name || "default_key" \%\]' AS key,
        COUNT(*) AS count
--%% END ## query.do_select_count }}}
    FROM
        (
            WITH
            _all AS (
                SELECT
                    *
                FROM
                    read_parquet(
--%%                FILTER replace("brick/[^']+?\.parquet", output.all )
                        'brick/analysis-20130927/ctgov-studies-all.parquet'
--%%                END
                    )
                WHERE
--%%            FILTER replace("2008-01-01", date.start)
--%%                FILTER replace("2012-09-01", date.stop )
                    1 = 1 -- Needed for dynamic AND clauses
--%%            UNLESS query.disable_filter_first_recruitment_status # {{{
                    AND overall_status != 'WITHDRAWN'
--%%            END ## query.disable_filter_first_recruitment_status }}}
--%%            UNLESS query.disable_filter_start_date # {{{
                    AND (
                        try_parse_date(primary_completion_date) :: DATE >= '2008-01-01'
                        OR primary_completion_date IS NULL
                        AND (
                            try_parse_date(completion_date) :: DATE >= '2008-01-01'
                            OR completion_date IS NULL
                        )
                    )
--%%            END ## query.disable_filter_start_date }}}
--%%            UNLESS query.disable_filter_study_design # {{{
                    AND study_type = 'INTERVENTIONAL'
--%%            END ## query.disable_filter_study_design }}}
--%%            UNLESS query.disable_filter_phase # {{{
                    AND phase NOT IN ('EARLY_PHASE1', 'PHASE1')
--%%            END ## query.disable_filter_phase }}}
--%%            UNLESS query.disable_filter_second_recruitment_status # {{{
                    AND overall_status IN ('TERMINATED', 'COMPLETED')
--%%            END ## query.disable_filter_second_recruitment_status }}}
--%%            UNLESS query.disable_filter_end_date # {{{
                    AND (
                        try_parse_date(primary_completion_date) :: DATE < '2012-09-01'
                        OR primary_completion_date IS NULL
                        AND (
                            try_parse_date(completion_date) :: DATE < '2012-09-01'
                            OR completion_date IS NULL
                        )
                    )
--%%            END ## query.disable_filter_end_date }}}
--%%            UNLESS query.disable_filter_verification_date # {{{
                    AND (
                        primary_completion_date IS NOT NULL
                        OR completion_date IS NOT NULL
                        OR (
                            try_parse_date(verification_date) :: DATE >= '2008-01-01'
                            AND try_parse_date(verification_date) :: DATE < '2012-09-01'
                        )
                    )
--%%            END ## query.disable_filter_verification_date }}}
--%%                END ## date.stop
--%%            END ## date.start
            ),
            aact AS (
                SELECT
                    f.nct_id,
                    any_value(v.has_us_facility) as has_us_facility,
                    any_value(disposition_first_submitted_date) as extension_date2,
                    any_value(f.country) as country,
                FROM
                    pg.ctgov.calculated_values v
                    JOIN pg.ctgov.facilities f ON v.nct_id = f.nct_id
                    JOIN pg.ctgov.studies s ON v.nct_id = s.nct_id
                WHERE
                    v.has_us_facility IS NOT NULL
                GROUP BY
                    f.nct_id
            )
            SELECT
                *
            FROM
                _all a
--%%            UNLESS query.disable_filter_oversight # {{{
                JOIN aact ct ON ct.nct_id = a.nct_id
--%%            END ## query.disable_filter_oversight }}}
            WHERE
                1 = 1 -- Needed for dynamic AND clauses
--%%            UNLESS query.disable_filter_oversight # {{{
                AND
                (
                    (is_fda_regulated_drug   = true AND primary_purpose = 'INTERVENTIONAL')
                OR  (is_fda_regulated_device = true)
                )
                AND a.has_us_facility = true
                OR ct.has_us_facility = true
--%%            END ## query.disable_filter_oversight }}}
        )
--%% UNLESS query.do_select_count # {{{
--%%   FILTER replace("brick/[^']+?\.parquet", output.item('hlact-filtered') )
) TO 'brick/analysis-20130927/ctgov-studies-hlact.parquet' (FORMAT PARQUET)
--%%   END ## FILTER
--%% END ## query.do_select_count }}}
--%% # vim: fdm=marker
