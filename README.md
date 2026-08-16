# Bulk RNA-seq — training project

Learning the upstream bulk RNA-seq workflow end to end: ENA retrieval →
QC → transcript-level quantification → gene-level differential expression.

Reproducing a published dataset (GSE50499) so that results can be checked
against the original findings rather than merely "looking plausible".

## Dataset

- **Accession**: GSE50499 (SRA study: SRP029367)
- **Design**: 8 biological samples, single-end 100 bp, sequenced in technical
  duplicate (16 runs)
- **Retrieval**: FASTQ files pulled directly from ENA rather than converted from
  SRA — no format conversion, and ENA checksums apply to the downloaded files.
- **Integrity**: each file verified against the ENA md5; the check script
  distinguishes missing, incomplete and corrupted files and applies the
  matching repair (fresh download vs. resume), then re-verifies.
- **Rationale**: knockdown design provides a built-in positive control —
  the targeted gene must come out down-regulated, or the pipeline is wrong.

## Workflow

| Step | Script | Environment | Status | Checkpoint |
|------|--------|-------------|--------|------------|
| Metadata & URLs | `scripts/00_metadata.sh` | base | done | 16 runs in report |
| Download | `scripts/01_download.sh` | `fastq_download` | done | 16/16 files present |
| Integrity check | `scripts/02_check.sh` | base | done | 16/16 md5 match ENA |
| QC | `scripts/03_qc.sh` | `qc` | done | 100 bp, adapter <2% |
| Salmon index | `scripts/04_index.sh` | `salmon` | not started | decoy-aware, k=31 |
| Quantification | `scripts/05_quant.sh` | `salmon` | not started | mapping rate > 70% |
| Differential expression | `scripts/06_de.R` | `de` | not started | target gene down |

Technical duplicates are quantified per run and collapsed to 8 biological
samples in the DE step, not merged at the FASTQ level — this preserves
inter-run correlation as a QC check.

## Reproducing

```bash
conda env create -f envs/fastq_download.yml
conda env create -f envs/qc.yml
./scripts/00_metadata.sh
./scripts/01_download.sh                        # ~25 GB, not tracked in git
./scripts/02_check.sh && ./scripts/03_qc.sh
```

Each script exits non-zero on failure, so steps can be chained with `&&`
without risking a downstream step running on bad data.

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