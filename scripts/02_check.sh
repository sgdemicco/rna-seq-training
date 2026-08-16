#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUTDIR="raw_data"
LOGDIR="logs"
ENAREP="meta/ena_report.tsv"
SRR="meta/SRR_Acc_List.txt"

fail=0

diagnose() {
	local srr="$1" #I declare a local variable for the function: the code that follows will not be affected from the value 
	local actual_bytes ena_bytes url

	actual_bytes=$(stat -c%s "$OUTDIR/${srr}.fastq.gz") #Take actual bytes from my data
        ena_bytes=$(awk -F'\t' -v b="$srr" 'NR>1 && $1==b { print $4 }' "$ENAREP")
        url=$(awk -F'\t' -v b="$srr" 'NR>1 && $1==b { print "https://"$2 }' "$ENAREP")

        	if [ "$actual_bytes" -lt "$ena_bytes" ]; then
                	echo -e "$srr is incomplete\n Completing download"
                        aria2c "$url"\
                                --dir="$OUTDIR" \
                                --continue=true \
                                --auto-file-renaming=false \
                                --max-connection-per-server=4 \
                                --split=4

		else
                	echo -e "$srr is corrupt\n Downloading $srr again"
                        rm "$OUTDIR/${srr}.fastq.gz"
                        aria2c "$url"\
                                --dir="$OUTDIR" \
                                --continue=true \
                                --auto-file-renaming=false \
                                --max-connection-per-server=4 \
                                --split=4
		fi
	}

while read -r srr; do
	[ -z "$srr" ] && echo "No SRR identified" && continue

	if
                        [ ! -f "$OUTDIR/${srr}.fastq.gz" ]; then
                        echo -e "$srr is missing\nDownloading $srr"
                        aria2c $(awk -F'\t' -v b="$srr" 'NR>1 && $1==b { print "https://"$2 }' "$ENAREP")\
                                --dir="$OUTDIR" \
                                --continue=true \
                                --auto-file-renaming=false \
                                --max-connection-per-server=4 \
                                --split=4
        fi

	actual_md5=$(md5sum "$OUTDIR/${srr}.fastq.gz" | cut -d' ' -f1) #Take actual md5sum, cut take only the first field
	ena_md5=$(awk -F'\t' -v s="$srr" 'NR>1 && $1==s { print $3 }' "$ENAREP")

	[ -z "$actual_md5" ] && { echo "Missing $srr md5 actual value"; continue; }
	[ -z "$ena_md5" ] && { echo "Missing $srr md5 ENA value"; continue; }

	if [ "$actual_md5" = "$ena_md5" ]; then
		echo "$srr OK"
	else
			echo -e "$srr FAILED\n Starting finding problems"
		diagnose "$srr"

		new_md5=$(md5sum "$OUTDIR/${srr}.fastq.gz" | cut -d' ' -f1)

			if [ "$new_md5" = "$ena_md5" ]; then
				echo "$srr repaired"
			else
				echo "$srr is stil failing afer repair"
				fail=1
			fi
	fi
done < $SRR

exit $fail
