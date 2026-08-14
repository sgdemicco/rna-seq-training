
#1 Let's start downloading files from NCBI using accession number  with script 1_download.sh
-Create directories if not there
-Verify that accession number list is valid and not empty
-Verify if the content of each SRR was not already downloaded
-Download with fasterq-dump (too slow, trying parallel-fasterq-dump), time optimization: parallel the single SRA fragmenting it
and using --gzip to compress while downloading
-Trying --pzip -p 6 to parallelize compression (pzip is not available for parallel-fasterq-dump)
-Trying to switch from SRA to ENA. ENA directly download fastq.
-Need to create a new script to get metadata

