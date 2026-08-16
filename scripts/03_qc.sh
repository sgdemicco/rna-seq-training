#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

LOGDIR="logs"

LOGFILE="$LOGDIR/$(basename "$0" .sh).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== $(date) ==="

mkdir -p results/fastqc
fastqc -o results/fastqc/ -t 6 raw_data/*.fastq.gz #Using fastqc to check the quality of the data, 
#-o output directory, -t number of threads, *.fastq.gz all the files with this extension
multiqc results/fastqc/*_fastqc.zip -o results/multiqc #Using multiqc to combine the results of fastqc into one report  