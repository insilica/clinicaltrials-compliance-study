# clinicaltrials-compliance-study

Steps towards reproducing results of:

> Anderson ML, Chiswell K, Peterson ED, Tasneem A, Topping J, Califf RM.
> Compliance with results reporting at ClinicalTrials.gov. N Engl J Med. 2015
> Mar 12;372(11):1031-9.
> [doi: 10.1056/NEJMsa1409364](https://doi.org/10.1056/NEJMsa1409364).
> [PMID: 25760355](https://pubmed.ncbi.nlm.nih.gov/25760355/);
> [PMCID: PMC4508873](http://www.ncbi.nlm.nih.gov/pmc/articles/pmc4508873/).

## Selection of Clinical Trials to Include

Diagram from original paper:

[![Figure 1: Clinical Trials Included in the Study.](https://www.nejm.org/cms/10.1056/NEJMsa1409364/asset/bad8a8de-730f-4b12-b225-a7b8671ba351/assets/images/large/nejmsa1409364_f1.jpg)](https://www.nejm.org/doi/10.1056/NEJMsa1409364#f01)

```shell

make run-psql PGDATABASE=aact_20240430 FILE=aact2024_init.sql

make run-psql PGDATABASE=aact_20240430 FILE=aact2024_init.sql | sed  's/|/\t/g' | awk 'NR != 2' | head -n -2 | vd -f tsv

vd ./brick/anderson2015/proj_results_reporting_studies_Analysis_Data.parquet

make run-psql PGDATABASE=aact_20170105 FILE=aact2017_init.sql


```
