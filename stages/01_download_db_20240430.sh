#!/usr/bin/env bash
# Script to download files

# Get local path
localpath=$(pwd)
echo "Local path: $localpath"

downloadpath="$localpath/download"
echo "Download path: $downloadpath"
mkdir -p $downloadpath

mkdir -p $downloadpath/aact/db-dump
wget "https://ctti-aact.nyc3.digitaloceanspaces.com/b3eaknxyv33k9ah4hckm4igb1ozq" \
  -O $downloadpath/aact/db-dump/20240430_clinical_trials.zip

echo "Download done."
