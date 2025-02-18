# clinicaltrials-compliance-study

## Paper

**Compliance with Results Reporting at ClinicalTrials.gov Before and After the 2017 FDAAA Final Rule: A Comparative Analysis**

- Publication: [Compliance with Results Reporting at ClinicalTrials.gov Before and After the 2017 FDAAA Final Rule: A Comparative Analysis](https://publichealth.realclearjournals.org/research-articles/2025/01/compliance-with-results-reporting-at-clinicaltrials-gov-before-and-after-the-2017-fdaaa-final-rule-a-comparative-analysis/)
- DOI: <https://doi.org/10.70542/rcj-japh-art-vr3aga>


## Description

Steps towards reproducing results of:

> Anderson ML, Chiswell K, Peterson ED, Tasneem A, Topping J, Califf RM.
> Compliance with results reporting at ClinicalTrials.gov. N Engl J Med. 2015
> Mar 12;372(11):1031-9.
> [doi: 10.1056/NEJMsa1409364](https://doi.org/10.1056/NEJMsa1409364).
> [PMID: 25760355](https://pubmed.ncbi.nlm.nih.gov/25760355/);
> [PMCID: PMC4508873](http://www.ncbi.nlm.nih.gov/pmc/articles/pmc4508873/).

Report slides at: https://docs.google.com/presentation/d/1q_pNKA4MwdY39k_b7HetAq3R2V9vRUzMT_9Pc98CN9I

## Requirements

1. Docker (`docker`)
2. DVC (`dvc`)
3. PostgreSQL client (`psql`)

## Build local database

1. Copy `.env.template` to `.env` and edit (note the `DOCKER_POSTGRES_DATA_DIR` variable).

2. Run the following to download the data:

```shell
dvc pull # or dvc repro
```

3. Start the PostgreSQL server and restore the database dumps.

```shell
make docker-compose-up docker-load-data
```

## Selection of Clinical Trials to Include

Diagram from original paper:

[![Figure 1: Clinical Trials Included in the Study.](https://www.nejm.org/cms/10.1056/NEJMsa1409364/asset/bad8a8de-730f-4b12-b225-a7b8671ba351/assets/images/large/nejmsa1409364_f1.jpg)](https://www.nejm.org/doi/10.1056/NEJMsa1409364#f01)

```shell

make run-psql PGDATABASE=aact_20240430 FILE=sql/aact2024_init.sql

# NOTE: `vd` is VisiData
make run-psql-csv PGDATABASE=aact_20240430 FILE=sql/aact2024_init.sql | vd -f csv

vd ./brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet

make run-psql PGDATABASE=aact_20170105 FILE=sql/aact2017_init.sql


```

---

FDAAA 801 violations using the `studies.fdaaa801_violation` column:

```shell

make run-psql PGDATABASE=aact_20240430 FILE=sql/fdaaa801-violation.sql

```
