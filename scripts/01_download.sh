#!/usr/bin/env bash
set -euo pipefail #interrupt process if it fails in the middle and not in the end
cd "$(dirname "$0")/.." #set working directory in the mother folder, easy access to the tree

#defining variables
OUTPUT="raw_data"
LOGDIR="logs"
ENALINKS="meta/ena_links.txt"
SRR="meta/SRR_Acc_List.txt"

#create directory if not existing
mkdir -p raw_data
mkdir -p logs
echo "Working directory created"

#use aria2c to parallel
aria2c \
	--input-file="$ENALINKS" \
    	--dir="$OUTPUT" \
    	--max-connection-per-server=4 \
    	--split=4 \
    	--min-split-size=20M \
    	--max-concurrent-downloads=4 \
    	--continue=true \
    	--auto-file-renaming=false \
    	--file-allocation=none \
    	--log="$LOGDIR/aria2.log" \
    	--log-level=notice \
    	--summary-interval=30 \
    	--retry-wait=5 \
    	--max-tries=5 \
    	--connect-timeout=30 \

