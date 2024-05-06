#!/usr/bin/env bash
# Script to download files

# Get local path
localpath=$(pwd)
echo "Local path: $localpath"

downloadpath="$localpath/download"
echo "Download path: $downloadpath"
mkdir -p $downloadpath

# Oldest database dump available from <https://aact.ctti-clinicaltrials.org/snapshots>.
mkdir -p $downloadpath/aact/db-dump
wget "https://ctti-aact.nyc3.digitaloceanspaces.com/zyxb0icr0b8tbx62lp0qo4u8kkns" \
  -O $downloadpath/aact/db-dump/20170105_clinical_trials.zip

echo "Download done."
