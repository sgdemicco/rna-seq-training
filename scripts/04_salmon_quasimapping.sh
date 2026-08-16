#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

#Changing conventions to let salmon perfrom I/O operations correctly
export LC_ALL=C
export LANG=C

OUTDIR="results/quant"
LOGDIR="logs/salmon_quasimapping"
REFERENCE="reference/GRCh38_salmon_index"
SRR="meta/SRR_Acc_List.txt"

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
    echo "Skipping generation of complete transcriptome"
else
    echo "Generating complete transcriptome"
    cat "$REFERENCE/Homo_sapiens.GRCh38.cdna.all.fa"\
    <(gunzip -c "$REFERENCE/Homo_sapiens.GRCh38.genome.fa.gz") \
    > "$REFERENCE/Homo_Sapiens_Complete.txt"
fi

salmon index -t "$REFERENCE/Homo_Sapiens_Complete.txt" \
    -d "$REFERENCE/Homo_Sapiens_Decoys.txt" \
    -i "$REFERENCE/salmon_index" \
    -k 31 \
    -p 6

while read srr; do
    salmon quant -i "$REFERENCE/Homo_sapiens.GRCh38.cdna.all.fa" \
    -l A \ #Automatically identifies library type
    -r "$srr" \
    -o "$OUTDIR/$srr" \
    --useVBOpt \ #use variational Bayesian EM rather than standard, more accurate
	--seqBias \ #remove sequence-specific bias
	--validateMappings #keep only good reads

done < "$SRR"