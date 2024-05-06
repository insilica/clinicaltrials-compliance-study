# clinicaltrials-compliance-study

Steps towards reproducing results of:

> Anderson ML, Chiswell K, Peterson ED, Tasneem A, Topping J, Califf RM.
> Compliance with results reporting at ClinicalTrials.gov. N Engl J Med. 2015
> Mar 12;372(11):1031-9. [doi: 10.1056/NEJMsa1409364](https://doi.org/10.1056/NEJMsa1409364).
> PMID: 25760355; PMCID: PMC4508873.

## Filtering

```shell

make run-psql PGDATABASE=aact_20240430 FILE=aact2024_init.sql

make run-psql PGDATABASE=aact_20170105 FILE=aact2017_init.sql


```
