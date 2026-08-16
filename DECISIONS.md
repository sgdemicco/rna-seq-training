---

## 2026-08-16 — Integrity checking

**Incident:** the first retry loop deleted the local file before
re-downloading. A download that then failed left nothing behind
(SRR960456 lost). Root cause was a wrong premise: md5 verification was
being applied to files obtained through `fasterq-dump` and recompressed
locally, so the checksums could never match — ENA publishes the md5 of
*its own* gzip, not of the underlying reads.

**Decision: never destroy before verifying.**
Downloads now go to a temporary location; the existing file is replaced
only after the new one passes verification.

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
After any repair the md5 is recomputed; only a matching checksum counts
as repaired.

**Incident:** ENA links were generated from a study accession rather than
from the run list, yielding 73 unrelated runs (SRR942xxx). Fixed by building
the API query from `SRR_Acc_List.txt` directly. Lesson: always check the
line count of a generated URL list before feeding it to a downloader.

**Result: 16/16 files verified against ENA checksums.**

**Open question:** ENA md5 confirms the file matches what ENA published,
not that the FASTQ itself is well-formed. Read-count and last-record checks
are still to be added.
