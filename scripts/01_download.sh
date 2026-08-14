#!/usr/bin/env bash
set -euo pipefail #interrupt process if it fails in the middle and not in the end
cd "$(dirname "$0")/.." #set working directory in the mother folder, easy access to the tree

#defining variables
OUTPUT="raw_data"
LOGDIR="logs"
SRRFILE="meta/SRR_Acc_List.txt"

#create directory if not existing
mkdir -p raw_data
mkdir -p logs
echo "Working directory created"

#while cycle to read SRR identifiers
while read -r srr #declare each SRR as a variable in the cycle
do
	[ -z "$srr" ] && continue #if line is empty, skip (-z says the string is zero length)
	#if SRR is already in the directory, skip
		if [ -f "$OUTPUT/${srr}.fastq.gz" ]; then
		echo "$srr already downloaded"
continue
fi
	echo "Downloading $srr"
	#Download with accession number using parallel-fastq-dump
	parallel-fastq-dump --sra-id "$srr" --outdir "$OUTPUT" --gzip --threads 6 #Using 6/8 threads of my CPU (Ctrl+Shift+Esc to verify threads)
	echo "$srr downloaded and compressed"

done < "$SRRFILE"
