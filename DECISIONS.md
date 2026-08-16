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

---

## 2026-08-16 — Integrity checking

**Incident:** the first retry loop deleted the local file before
re-downloading. A download that then failed left nothing behind
(SRR960456 lost). Root cause was a wrong premise: md5 verification was
being applied to files obtained through `fasterq-dump` and recompressed
locally, so the checksums could never match — ENA publishes the md5 of
*its own* gzip, not of the underlying reads.

**Decision: never destroy before verifying.**
Downloads go to a temporary location; the existing file is replaced only
after the new one passes verification.

**Decision: diagnose before repairing** (`02_check.sh`)

Three mutually exclusive states, each with its own repair:

| State | Detected by | Repair |
|-------|-------------|--------|
| missing | file absent | fresh download |
| incomplete | local bytes < `fastq_bytes` | resume (`--continue`) |
| corrupted | bytes match, md5 does not | delete and re-download |

The distinction matters in practice: resuming an incomplete 2 GB file takes
seconds, re-downloading it takes minutes. Tests are ordered cheapest first —
existence, then size, then checksum (which reads the whole file).

**Decision: repairs are re-verified.**
After any repair the md5 is recomputed; only a matching checksum counts as
repaired. Scripts exit non-zero on failure so steps can be chained safely.

**Incident:** ENA links were generated from a study accession rather than
from the run list, yielding 73 unrelated runs (SRR942xxx). Fixed by building
the API query from `SRR_Acc_List.txt` directly. Lesson: always check the
line count of a generated URL list before feeding it to a downloader.

**Result: 16/16 files verified against ENA checksums.**

**Open question:** ENA md5 confirms the file matches what ENA published,
not that the FASTQ itself is well-formed. Read-count and last-record checks
are still to be added.

---

## 2026-08-16 — Quality control

FastQC on all 16 runs, aggregated with MultiQC.

- Read length: 100 bp, uniform across all runs → Salmon index `-k 31` (default)
- GC content: 47–48%, consistent with human RNA-seq, no contamination signal
- Duplication: 41–53%, expected for RNA-seq (highly expressed genes)
- Adapter content: <2% in all runs

**Decision: no trimming step.**
Adapter contamination is below the threshold where trimming improves results,
and Salmon's selective alignment tolerates residual 3' adapter without
requiring full-length alignment.

**Observation:** read counts pair up as 27.4/25.3, 16.2/14.9, 20.8/19.2,
19.3/17.8, 11.0/10.2, 18.8/17.3, 16.1/14.8, 12.4/11.5 M — eight pairs of
consecutive accessions, second run consistently ~8% smaller. Consistent with
technical duplicates being two lanes of the same library.

**Note:** SRR960455/456 show higher duplication (52.7/51.4%) and 18% failed
modules vs 9% elsewhere; they also have the highest read counts, so this is
likely depth-driven.

**Environment issue:** `multiqc` was resolving to `/usr/bin/multiqc` (a broken
system-wide pip install) instead of the conda env, producing reports with
missing JS assets. Fixed by installing multiqc into the `qc` env.
Lesson: check `which` before debugging a tool's behaviour.