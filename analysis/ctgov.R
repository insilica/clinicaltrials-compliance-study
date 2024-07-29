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
  survminer,
  ggsurvfit,
  forcats,
  stringr,
  broom,
  tidyr,
  assertthat
)

source('analysis/ctgov/dateutil.R')
source('analysis/ctgov/util.R')

source('analysis/ctgov/preprocess/anderson2015.R')
source('analysis/ctgov/preprocess/jsonl_derived.R')

source('analysis/ctgov/survival.R')
source('analysis/ctgov/regression.R')
source('analysis/ctgov/preprocess/common.R')
