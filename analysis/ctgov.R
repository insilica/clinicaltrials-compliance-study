# ctgov.R

# Load necessary libraries
if (!require("pacman")) install.packages("pacman")
library(pacman)

pacman::p_load(
  arrow,
  dplyr,
  lubridate,
  survival,
  ggplot2,
  ggtext,
  survminer,
  ggsurvfit,
  forcats,
  stringr,
  blandr,
  broom,
  tidyr,
  assertthat,
  testthat,
  fs,
  glue,
  listr,
  logger,
  patchwork,
  purrr,
  rlang,
  scales,
  svglite,
  yaml
)

source('analysis/ctgov/dateutil.R')
source('analysis/ctgov/util.R')

## The following are used to handle two different schemas. Schemas here are
## used as column prefixes for tracking.

## `schema0` is the schema used in the Anderson 2015 dataset that is processed
## by `build-paper-data` stage (`stages/02_build-anderson2015.sh`).
source('analysis/ctgov/preprocess/anderson2015.R')

## `schema1` is the schema used via the data processed
## by `build-ctgov-studies-all` stage (`sql/create_cthist_all.sql`).
source('analysis/ctgov/preprocess/jsonl_derived.R')

## The two schemas are merged into a final schema `common` for what is used by
## the analysis.
source('analysis/ctgov/survival.R')
source('analysis/ctgov/regression.R')
source('analysis/ctgov/preprocess/common.R')

source('analysis/ctgov/anderson2015_data.R')

source('analysis/ctgov/process_windows.R')
source('analysis/ctgov/plot_scatterline.R')
source('analysis/ctgov/plot_compare_logistic.R')
source('analysis/ctgov/plot_stacked_chart.R')
