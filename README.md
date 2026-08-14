# Bulk RNA-seq — training project

Learning the upstream bulk RNA-seq workflow end to end: ENA retrieval →
QC → transcript-level quantification → gene-level differential expression.

Reproducing a published dataset (GSE50499) so that results can be checked
against the original findings rather than merely "looking plausible".

## Dataset

- **Accession**: GSE50499 (SRA study: SRP...)
- **Design**: 8 biological samples, single-end, sequenced in technical duplicate (16 runs)
- **Retrieval**: FASTQ files pulled directly from ENA rather than converted from
  SRA — no format conversion, and ENA checksums apply to the downloaded files.
- **Rationale**: knockdown design provides a built-in positive control —
  the targeted gene must come out down-regulated, or the pipeline is wrong.

## Workflow

| Step | Script | Environment |
|------|--------|-------------|
| Metadata & URLs | `scripts/00_metadata.sh` | base |
| Download | `scripts/01_download.sh` | `fastq_download` |
| Integrity check | `scripts/02_check.sh` | base |
| QC | `scripts/03_qc.sh` | `qc` |
| Salmon index | `scripts/04_index.sh` | `salmon` |
| Quantification | `scripts/05_quant.sh` | `salmon` |
| Differential expression | `scripts/06_de.R` | `de` |

Technical duplicates are quantified per run and collapsed to 8 biological
samples in the DE step, not merged at the FASTQ level — this preserves
inter-run correlation as a QC check.

## Reproducing

```bash
conda env create -f envs/fastq_download.yml
./scripts/00_metadata.sh
./scripts/01_download.sh    # ~25 GB, not tracked in git
./scripts/02_check.sh
```

## Environment

Developed on WSL2 (Ubuntu), 8 cores / 24 GB RAM.
Salmon index built decoy-aware; requires ~16 GB during construction.

## Notes

Methodological decisions, including approaches that were tried and
abandoned, are logged in `DECISIONS.md`.
Raw data, reference files and Salmon indices are gitignored;
`meta/` contains everything needed to regenerate them.

## Status

Work in progress — this is a learning repository, not a validated pipeline.
