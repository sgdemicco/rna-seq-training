#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

LOGDIR="logs"

LOGFILE="$LOGDIR/$(basename "$0" .sh).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== $(date) ==="

if [ -f "meta/ena_report.tsv" ]; then
	echo "Metadata already available"
else
	echo "Retrieving ENA metadata of SRP029367"
	curl -sf "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRP029367&result=read_run&fields=run_accession,fastq_ftp,fastq_md5,fastq_bytes,read_count&format=tsv" \
  	> meta/ena_report.tsv
	echo "Retrieved ENA meta"
fi

#Take the second column, with downloading link
awk 'NR >1 {printf "https://%s\n", $2}' meta/ena_report.tsv > meta/ena_links.txt
echo "Links obtained" 
