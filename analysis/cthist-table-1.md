Clinical Trials Compliance Study
================

## Highly-Likely Applicable Clinical Trials Analysis

Table 1 of the [original
article](https://www.nejm.org/doi/full/10.1056/NEJMsa1409364#sec-2)
groups the 13,327 HLACTs in three categories: all trials, those that
reported results in the twelve-month reporting window, and those that
reported results in the five-year reporting window.

### All trials categorized and ranked by purpose

The total set of HLACTs found in the Clinical Trials database (count:
14467) demonstrate a similar spread of `primary_purpose` as the original
Anderson 2015 dataset of 13327 HLACTs.

#### Trial purpose

<table class="table" style>
<thead>
<tr>
<th style="text-align:left;">
primary_purpose
</th>
<th style="text-align:left;">
All
</th>
<th style="text-align:left;">
Twelve months
</th>
<th style="text-align:left;">
Five years
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
TREATMENT
</td>
<td style="text-align:left;">
74.18
</td>
<td style="text-align:left;">
81.30
</td>
<td style="text-align:left;">
80.08
</td>
</tr>
<tr>
<td style="text-align:left;">
PREVENTION
</td>
<td style="text-align:left;">
9.45
</td>
<td style="text-align:left;">
7.12
</td>
<td style="text-align:left;">
7.39
</td>
</tr>
</tbody>
</table>

### Intervention type

The main inclusion criterion for the original study was that the trial
have an interventional study design if studying a drug. The breakdown of
intervention type for the current HLACT dataset is as follows:

<table class="table" style>
<thead>
<tr>
<th style="text-align:left;">
intervention_type
</th>
<th style="text-align:left;">
All
</th>
<th style="text-align:left;">
One year
</th>
<th style="text-align:left;">
Five years
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
DRUG
</td>
<td style="text-align:left;">
52.73
</td>
<td style="text-align:left;">
68.09
</td>
<td style="text-align:left;">
63.47
</td>
</tr>
<tr>
<td style="text-align:left;">
DEVICE
</td>
<td style="text-align:left;">
7.73
</td>
<td style="text-align:left;">
8.98
</td>
<td style="text-align:left;">
9.60
</td>
</tr>
<tr>
<td style="text-align:left;">
BIOLOGICAL
</td>
<td style="text-align:left;">
3.62
</td>
<td style="text-align:left;">
5.02
</td>
<td style="text-align:left;">
4.61
</td>
</tr>
</tbody>
</table>

### Trial phases

Trials were considered if they were not in Phase 0, or Early Phase 1.

<table class="table" style>
<thead>
<tr>
<th style="text-align:left;">
phase
</th>
<th style="text-align:left;">
All
</th>
<th style="text-align:left;">
One year
</th>
<th style="text-align:left;">
Five years
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
PHASE1; PHASE2
</td>
<td style="text-align:left;">
6.207230
</td>
<td style="text-align:left;">
4.56
</td>
<td style="text-align:left;">
5.53
</td>
</tr>
<tr>
<td style="text-align:left;">
PHASE2
</td>
<td style="text-align:left;">
31.741204
</td>
<td style="text-align:left;">
27.40
</td>
<td style="text-align:left;">
32.23
</td>
</tr>
<tr>
<td style="text-align:left;">
PHASE2; PHASE3
</td>
<td style="text-align:left;">
2.536808
</td>
<td style="text-align:left;">
1.58
</td>
<td style="text-align:left;">
2.38
</td>
</tr>
<tr>
<td style="text-align:left;">
PHASE3
</td>
<td style="text-align:left;">
18.663164
</td>
<td style="text-align:left;">
28.65
</td>
<td style="text-align:left;">
23.70
</td>
</tr>
<tr>
<td style="text-align:left;">
PHASE4
</td>
<td style="text-align:left;">
12.131057
</td>
<td style="text-align:left;">
21.12
</td>
<td style="text-align:left;">
16.21
</td>
</tr>
<tr>
<td style="text-align:left;">
NA
</td>
<td style="text-align:left;">
28.720536
</td>
<td style="text-align:left;">
16.70
</td>
<td style="text-align:left;">
19.94
</td>
</tr>
</tbody>
</table>

### Trial site

Many trials in the Clinical Trials dataset were conducted at multiple
sites, sometimes across several countries and continents. A major factor
in the original analysis was the presence of at least one US site in the
trial.

<table class="table" style>
<thead>
<tr>
<th style="text-align:left;">
has_us_facility
</th>
<th style="text-align:left;">
All
</th>
<th style="text-align:left;">
One year
</th>
<th style="text-align:left;">
Five years
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
TRUE
</td>
<td style="text-align:left;">
99.25
</td>
<td style="text-align:left;">
98.65
</td>
<td style="text-align:left;">
99.12
</td>
</tr>
<tr>
<td style="text-align:left;">
</td>
<td style="text-align:left;">
0.54
</td>
<td style="text-align:left;">
1.16
</td>
<td style="text-align:left;">
0.64
</td>
</tr>
<tr>
<td style="text-align:left;">
FALSE
</td>
<td style="text-align:left;">
0.21
</td>
<td style="text-align:left;">
0.19
</td>
<td style="text-align:left;">
0.23
</td>
</tr>
</tbody>
</table>

### Funding source

The available data enumerates three sponsor types for clinical trials:
National Institutes of Health (NIH), industry, and other government or
academic institution. In Anderson, 2015, industry-led trials showed much
higher compliance with reporting requirements during the initial
twelve-month period than government- or academic-run trials. Over the
five-year period, these gaps closed, but total reporting rates were
still less than 50%.

<table class="table" style>
<thead>
<tr>
<th style="text-align:left;">
funding_source
</th>
<th style="text-align:left;">
All
</th>
<th style="text-align:left;">
One year
</th>
<th style="text-align:left;">
Five years
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
OTHER
</td>
<td style="text-align:left;">
47.55
</td>
<td style="text-align:left;">
32.37
</td>
<td style="text-align:left;">
42.52
</td>
</tr>
<tr>
<td style="text-align:left;">
INDUSTRY
</td>
<td style="text-align:left;">
41.67
</td>
<td style="text-align:left;">
60.60
</td>
<td style="text-align:left;">
45.87
</td>
</tr>
<tr>
<td style="text-align:left;">
NIH
</td>
<td style="text-align:left;">
5.10
</td>
<td style="text-align:left;">
4.98
</td>
<td style="text-align:left;">
6.07
</td>
</tr>
</tbody>
</table>

### Categorized by completion date

<table class="table" style>
<thead>
<tr>
<th style="text-align:left;">
primary_completion_date_imputed
</th>
<th style="text-align:left;">
All
</th>
<th style="text-align:left;">
One year
</th>
<th style="text-align:left;">
Five years
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
2008
</td>
<td style="text-align:left;">
20.07
</td>
<td style="text-align:left;">
16.79
</td>
<td style="text-align:left;">
17.94
</td>
</tr>
<tr>
<td style="text-align:left;">
2009
</td>
<td style="text-align:left;">
22.36
</td>
<td style="text-align:left;">
17.77
</td>
<td style="text-align:left;">
22.00
</td>
</tr>
<tr>
<td style="text-align:left;">
2010
</td>
<td style="text-align:left;">
22.11
</td>
<td style="text-align:left;">
21.58
</td>
<td style="text-align:left;">
22.52
</td>
</tr>
<tr>
<td style="text-align:left;">
2011
</td>
<td style="text-align:left;">
21.31
</td>
<td style="text-align:left;">
24.42
</td>
<td style="text-align:left;">
22.43
</td>
</tr>
<tr>
<td style="text-align:left;">
2012
</td>
<td style="text-align:left;">
14.14
</td>
<td style="text-align:left;">
19.44
</td>
<td style="text-align:left;">
15.10
</td>
</tr>
</tbody>
</table>
