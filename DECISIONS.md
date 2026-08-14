# Decisions log

Chronological record of methodological choices, including approaches
that were tried and abandoned.

---

## 2026-08-13 — Data retrieval

**Initial approach: NCBI SRA via accession list** (`01_download.sh`)

- Create output directories if missing
- Verify the accession list is non-empty and valid
- Skip runs already present on disk

**Iterations on speed:**

- `fasterq-dump` — too slow (~2.4 MiB/s), single-threaded conversion
- `parallel-fastq-dump` — splits each run into blocks processed in parallel;
  `--gzip` compresses during dump, removing a separate compression pass
- `pigz -p 6` — not applicable, `parallel-fastq-dump` handles compression internally

**Decision: switch from SRA to ENA.**

ENA serves FASTQ files directly, so no SRA→FASTQ conversion is needed.
Side benefit: ENA checksums refer to the exact files downloaded, so md5
verification becomes meaningful (it cannot work on locally recompressed
SRA output).

Required a separate metadata script to retrieve FTP URLs from the ENA Portal API.

---

## 2026-08-14 — Download tuning

**Decision: `aria2c` instead of `curl`.**

Multi-connection and multi-file parallelism, with resume support.

- 16 connections/file × 4 files: ENA refuses connections beyond ~16 total;
  rejected connections waste time reconnecting → ~2.4 MiB/s
- 4 connections/file × 4 files: no refusals → ~4.2 MiB/s

**Open question:** whether ~4.2 MiB/s is the line limit or a WSL2
networking ceiling. To test with `networkingMode=mirrored`.
