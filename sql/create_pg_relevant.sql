INSTALL postgres;

ATTACH 'postgresql://postgres:postgres@localhost:6432/aact_20240430' AS pg (TYPE postgres);

CREATE TABLE
    pg.ctgov.relevant_studies (
        "nctid" VARCHAR,
        "overall_status" VARCHAR,
        "status" VARCHAR,
        "enrolment_type" VARCHAR,
        "enrolment" INTEGER,
        "version_date" DATE,
        "version_number" INTEGER,
        "study_start_date" DATE,
        "primary_completion_date" DATE
    );

INSERT INTO
    pg.ctgov.relevant_studies (
        SELECT
            nctid,
            overall_status,
            "status",
            enrolment_type,
            enrolment,
            version_date,
            version_number,
            study_start_date,
            primary_completion_date
        FROM
            'work/relevant_study_records.parquet'
    );