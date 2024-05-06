#!/usr/bin/env bash
# Script to download files

# Get local path
localpath=$(pwd)
echo "Local path: $localpath"

downloadpath="$localpath/download"
echo "Download path: $downloadpath"
mkdir -p $downloadpath

# From <https://aact.ctti-clinicaltrials.org/shared_data/proj_results_reporting>.
mkdir -p $downloadpath/anderson2015
wget --content-disposition \
  -P $downloadpath/anderson2015 \
  "https://aact.ctti-clinicaltrials.org/datasets/40"  \
  "https://aact.ctti-clinicaltrials.org/attachments/21"

echo "Download done."
