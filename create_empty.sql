CREATE TABLE my_table (
    "nctid" VARCHAR,
    "overall_status" VARCHAR,
    "status" VARCHAR,
    "study_start_date_precision" VARCHAR,
    "primary_completion_date_precision" VARCHAR,
    "primary_completion_date_type" VARCHAR,
    "enrolment_type" VARCHAR,
    "enrolment" INTEGER,
    "min_age" VARCHAR,
    "max_age" VARCHAR,
    "sex" VARCHAR,
    "criteria" VARCHAR,
    "outcome_measures" VARCHAR,
    "overall_contacts" VARCHAR,
    "central_contacts" VARCHAR,
    "responsible_party" VARCHAR,
    "lead_sponsor" VARCHAR,
    "collaborators" VARCHAR,
    "whystopped" VARCHAR,
    "references" VARCHAR,
    "orgstudyid" VARCHAR,
    "secondaryids" VARCHAR,
    "version_date" DATE,
    "version_number" INTEGER,
    "study_start_date" DATE,
    "primary_completion_date" DATE
);

-- Copy the empty table to a Parquet file
COPY my_table TO 'work/empty.parquet' (FORMAT 'parquet');