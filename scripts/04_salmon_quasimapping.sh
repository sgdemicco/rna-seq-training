#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Force C locale: guarantees consistent sort order and decimal parsing
# across machines. Not related to the salmon 1.x crash (see DECISIONS.md).
export LC_ALL=C
export LANG=C

OUTDIR="results/quant"
LOGDIR="logs/salmon_quasimapping"
REFERENCE="reference/GRCh38_salmon_index"
SRR="meta/SRR_Acc_List.txt"
RAW="raw_data"

LOGFILE="$LOGDIR/$(basename "$0" .sh).log"
exec > >(tee -a "$LOGFILE") 2>&1

mkdir -p "$OUTDIR" "$REFERENCE" "$LOGDIR"

#Download reference drom ENSEMBL
if [ -f "$REFERENCE/Homo_sapiens.GRCh38.cdna.all.fa" ]; then
    echo "Skipping download of reference transcriptome"

else 
    echo "Downloading reference transcriptome"
    wget -O "$REFERENCE/Homo_sapiens.GRCh38.cdna.all.fa.gz" "https://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/cdna/Homo_sapiens.GRCh38.cdna.all.fa.gz"
    gzip -d "$REFERENCE/Homo_sapiens.GRCh38.cdna.all.fa.gz"
fi

if [ -f "$REFERENCE/Homo_sapiens.GRCh38.genome.fa.gz" ]; then
    echo "Skipping download of reference genome"

else 
    #Downloading genome to identify decoys to identify transcripts coming from non-mature RNA
    echo "Downloading reference genome"
    wget -O "$REFERENCE/Homo_sapiens.GRCh38.genome.fa.gz" "https://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz"
fi

if [ -f "$REFERENCE/Homo_Sapiens_Decoys.txt" ]; then
    echo "Skipping generation of decoy list"
else
    echo "Generating decoy list"
    zcat "$REFERENCE/Homo_sapiens.GRCh38.genome.fa.gz" \
    | grep "^>" \
    | cut -d' ' -f1 \
    | sed 's/>//g' \
    > "$REFERENCE/Homo_Sapiens_Decoys.txt" || true
fi

if [ -f "$REFERENCE/Homo_Sapiens_Complete.txt" ]; then
    echo "Skipping generation of genome+transcriptome"
else
    echo "Generating genome+transcriptome"
    cat "$REFERENCE/Homo_sapiens.GRCh38.cdna.all.fa"\
    <(gunzip -c "$REFERENCE/Homo_sapiens.GRCh38.genome.fa.gz") \
    > "$REFERENCE/Homo_Sapiens_Complete.txt"
fi

#create an array with all the required files of the index
index_requirement=(
    "$REFERENCE/salmon_index/index.ssi"
    "$REFERENCE/salmon_index/index.ctab"
    "$REFERENCE/salmon_index/index.refinfo"
    "$REFERENCE/salmon_index/index.ectab"
)

all_files_exist () {
    for file in "${index_requirement[@]}"; do
        if [ ! -f "$file" ]; then
            return 1
        fi
    done
    return 0
}

if [ -s "$REFERENCE/salmon_index" ] && all_files_exist "${index_requirement[@]}"; then
    echo "Using existing salmon index"
else
    echo "Creating salmon index"
    salmon index -t "$REFERENCE/Homo_Sapiens_Complete.txt" \
    -d "$REFERENCE/Homo_Sapiens_Decoys.txt" \
    -i "$REFERENCE/salmon_index" \
    -k 31 \
    -p 6 \
    --ramLimit 16
fi

#Automatically identifies library type
#use variational Bayesian EM rather than standard, more accurate
#remove sequence-specific bias
#keep only good reads

while read srr; do
    salmon quant \
    -i "$REFERENCE/salmon_index" \
    -l A \
    -r "$RAW/${srr}.fastq.gz" \
    -o "$OUTDIR/$srr" \
	--seqBias \
    --gcBias \
    -p 6

done < "$SRR"

multiqc -f -o results/multiqc results/fastqc results/quant