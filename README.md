k# Bulk RNA-seq — training project

Learning the upstream bulk RNA-seq workflow end to end: ENA retrieval →
QC → transcript-level quantification → gene-level differential expression.

Reproducing a published dataset (GSE50499) so that results can be checked
against the original findings rather than merely "looking plausible".

## Pipeline

```mermaid
graph TD
    A["ENA Portal API<br/><i>URLs, md5, read counts</i>"] --> B["aria2c download<br/>16 runs, ~25 GB"]
    B --> C{"integrity check<br/><i>md5 vs ENA</i>"}
    C -->|missing| B
    C -->|incomplete| B
    C -->|ok| D["FastQC + MultiQC<br/><i>100 bp, adapter &lt;2%</i>"]
    D --> E["Salmon index<br/><i>decoy-aware, k=31</i>"]
    E --> F["Salmon quant<br/><i>83.3–83.6% mapped</i>"]
    D --> J["STAR align<br/><i>genomic coordinates</i>"]
    J --> K["Qualimap<br/><i>exonic/intronic, 5'-3' bias</i>"]
    F --> G["tximport<br/><i>16 runs → gene counts</i>"]
    G --> H["collapseReplicates<br/><i>16 runs → 8 samples</i>"]
    H --> I["DESeq2<br/><i>KD vs Ctl, OE vs Ctl</i>"]

    R1["Ensembl 104 cDNA"] --> E
    R2["Ensembl 104 genome"] --> E
    R2 --> J
    R3["Ensembl 104 GTF"] --> J
    R3 --> K

    style C fill:#fff3cd,stroke:#856404
    style I fill:#d4edda,stroke:#155724
```

The STAR branch exists only for alignment QC: the counts used downstream come
from Salmon. STAR provides the genomic coordinates that Salmon discards, which
is what Qualimap needs to report exonic/intronic/intergenic proportions.

## Dataset

- **Accession**: GSE50499 (SRA study: SRP029367)
- **Design**: 8 biological samples, single-end 100 bp, sequenced in technical
  duplicate (16 runs). Three groups: MOV10 knockdown (n=2), MOV10
  overexpression (n=3), irrelevant siRNA control (n=3).
- **Library type**: SR (stranded, reverse) — detected empirically by Salmon
  with `-l A`, not assumed.
- **Retrieval**: FASTQ files pulled directly from ENA rather than converted from
  SRA — no format conversion, and ENA checksums apply to the downloaded files.
- **Integrity**: each file verified against the ENA md5; the check script
  distinguishes missing, incomplete and corrupted files and applies the
  matching repair (fresh download vs. resume), then re-verifies.
- **Reference**: Ensembl release 104, GRCh38 — cDNA, primary assembly and GTF,
  all from the same release for identifier consistency.
- **Index**: Salmon 2.0 decoy-aware, k=31. The genome is included as decoy
  sequence so that reads of intronic or genomic origin are discarded rather
  than forced onto the most similar transcript.
- **Rationale**: the knockdown/overexpression design provides a two-directional
  positive control — MOV10 must come out down in KD and up in OE, or the
  pipeline is wrong.

## Workflow

| Step | Script | Environment | Status | Checkpoint |
|------|--------|-------------|--------|------------|
| Metadata & URLs | `scripts/00_metadata.sh` | base | done | 16 runs in report |
| Download | `scripts/01_download.sh` | `fastq_download` | done | 16/16 files present |
| Integrity check | `scripts/02_check.sh` | base | done | 16/16 md5 match ENA |
| QC | `scripts/03_qc.sh` | `qc` | done | 100 bp, adapter <2% |
| Index + quantification | `scripts/04_salmon_quasimapping.sh` | `salmon` | done | 83.3–83.6% mapped |
| STAR + Qualimap (alignment QC) | `scripts/05_star.sh` | `star` | done | 16/16 aligned |
| MultiQC aggregation | `scripts/06_multiqc.sh` | `qc` | done | 4 modules × 16 reports |
| Differential expression | `scripts/07_de.R` | `deg` | not started | MOV10 down in KD, up in OE |

Technical duplicates are quantified per run and collapsed to 8 biological
samples in the DE step, not merged at the FASTQ level — this preserves
inter-run correlation as a QC check.

## Reproducing

```bash
conda env create -f envs/fastq_download.yml
conda env create -f envs/qc.yml
conda env create -f envs/salmon.yml
conda env create -f envs/star.yml

./scripts/00_metadata.sh
./scripts/01_download.sh                        # ~25 GB, not tracked in git
./scripts/02_check.sh && ./scripts/03_qc.sh
./scripts/04_salmon_quasimapping.sh             # index ~25 min, quant ~2 min/run
./scripts/05_star.sh                            # index ~45 min, ~5 min/run, ~35 GB of BAMs
./scripts/06_multiqc.sh
```

Each script exits non-zero on failure, so steps can be chained with `&&`
without risking a downstream step running on bad data.

## Environment

Developed on WSL2 (Ubuntu), 8 cores, 24 GB.

- Salmon 2.0 (Rust) builds its decoy-aware index with external sorting and
  peaks at ~6 GB RSS.
- STAR needs `--genomeSAsparseD 2` to fit; `--genomeLoad LoadAndKeep` does not
  work under WSL2 (shared-memory limits), so the index is reloaded per sample.
- Scripts set `LC_ALL=C` for consistent `sort` order and decimal parsing.

## Notes

Methodological decisions, including approaches that were tried and
abandoned, are logged in `DECISIONS.md`.

Raw data, reference files, indices and BAMs are gitignored;
`meta/` contains everything needed to regenerate them.

## Status

Work in progress — this is a learning repository, not a validated pipeline.
