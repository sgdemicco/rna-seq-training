# Bulk RNA-seq — training project

Learning the upstream bulk RNA-seq workflow end to end: SRA retrieval →
QC → transcript-level quantification → gene-level differential expression.

Reproducing a published dataset (GSE50499) so that results can be checked
against the original findings rather than merely "looking plausible".

## Dataset

- **Accession**: GSE50499 (SRA: SRP...)
- **Design**: 8 biological samples, single-end, sequenced in technical duplicate (16 runs)
- **Rationale**: knockdown design provides a built-in positive control —
  the targeted gene must come out down-regulated, or the pipeline is wrong.

## Workflow

| Step | Script | Environment |
|------|--------|-------------|
| Download | `scripts/00_download.sh` | `fastq_download` |
| QC | `scripts/01_qc.sh` | `qc` |
| Index | `scripts/02_index.sh` | `salmon` |
| Quantification | `scripts/03_quant.sh` | `salmon` |
| Differential expression | `scripts/04_de.R` | `de` |

## Reproducing

```bash
conda env create -f envs/salmon.yml
./scripts/00_download.sh    # ~25 GB, not tracked in git
./scripts/01_qc.sh
```

## Notes

Key methodological decisions are logged in `notes/DECISIONS.md`.
Raw data, reference files and Salmon indices are gitignored;
`meta/` contains everything needed to regenerate them.

## Status

Work in progress — this is a learning repository, not a validated pipeline.
