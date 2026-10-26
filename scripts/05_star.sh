#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

#Introducing STAR alignment + qualimap to identify the
#origin of reads (3'/5' bias, intronic regions ecc) avoiding technical biases

REFERENCE_GENOME="reference/GRCh38_salmon_index/Homo_sapiens.GRCh38.genome.fa.gz"
REFERENCE_GENOME_FA="reference/GRCh38_salmon_index/Homo_sapiens.GRCh38.genome.fa"
GENOME_GTF="reference/Homo_sapiens.GRCh38.gtf.gz"
GENOME_GTF_UNZIP="reference/Homo_sapiens.GRCh38.gtf"
STAR_INDEX="reference/GRCh38_STAR_index"
STAR_RESULTS="results/star"
QUALIMAP_RESULTS="results/qualimap"
LOGDIR="logs/star"
SRR="meta/SRR_Acc_List.txt"

mkdir -p "$STAR_INDEX" "$STAR_RESULTS" "$LOGDIR" "$QUALIMAP_RESULTS"

LOGFILE="$LOGDIR/$(basename "$0" .sh).log"
exec > >(tee -a "$LOGFILE") 2>&1


ensure () {
    local target="$1"; shift
    if [ -s "$target" ]; then
        echo "Skipping $target download"
    else
        echo "Downloading $target"
        "$@"
    fi
}

unzip_genome_reference () { gunzip -c "$REFERENCE_GENOME" > "$REFERENCE_GENOME_FA"; }
unzip_gtf () { gunzip -c "$GENOME_GTF" > "$GENOME_GTF_UNZIP"; }

ensure "$REFERENCE_GENOME" wget -O "$REFERENCE_GENOME" "https://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz"
ensure "$GENOME_GTF" wget -O "$GENOME_GTF" "https://ftp.ensembl.org/pub/release-104/gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz"
ensure "$REFERENCE_GENOME_FA" unzip_genome_reference
ensure "$GENOME_GTF_UNZIP" unzip_gtf

#Build STAR index
build_star_index() {
STAR --runMode genomeGenerate \
     --genomeFastaFiles "$REFERENCE_GENOME_FA" \
     --sjdbGTFfile "$GENOME_GTF_UNZIP" \
     --genomeSAsparseD 2 \
     --limitGenomeGenerateRAM 21474836480 \
     --genomeDir "$STAR_INDEX" \
     --runThreadN 6 \
     --sjdbOverhang 99
}

ensure "$STAR_INDEX/SAindex" build_star_index

#Perform STAR alignment
star_alignment () {
STAR --genomeDir "$STAR_INDEX" LoadAndKeep \
     --runThreadN 6 \
     --readFilesIn "raw_data/${srr}.fastq.gz" \
     --readFilesCommand zcat \
     --outFileNamePrefix "$STAR_RESULTS/${srr}_" \
     --outSAMtype BAM SortedByCoordinate \
     --outSAMunmapped Within \
     --outSAMattributes Standard
}

while read -r srr; do
	[ -z "$srr" ] && continue
	ensure "$STAR_RESULTS/${srr}_Aligned.sortedByCoord.out.bam" star_alignment "$srr"
done < "$SRR"

#Perform QC with qualimap, Java/R application with bot GUI and CLI to
#check the quality of alignment seq (supported for WGS/WES, RNA-seq, ChIP-seq)
#Examine SAM/BAM
while read -r srr; do
	[ -z "$srr" ] && continue
	mkdir -p "$QUALIMAP_RESULTS/$srr"
	ensure "$QUALIMAP_RESULTS/$srr/qualimapReport.html" \
	qualimap rnaseq \
		-outdir "$QUALIMAP_RESULTS" \
		-a proportional \
		-bam "$STAR_RESULTS/${srr}_Aligned.sortedByCoord.out.bam" \
		-p strand-specific-reverse \
		-gtf "$GENOME_GTF_UNZIP" \
		--java-mem-size=8G
done < "$SRR"

multiqc -f -o results/multiqc \
    results/fastqc \
    results/quant \
    results/star \
    results/qualimap
