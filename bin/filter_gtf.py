#!/usr/bin/env python
import logging
import argparse
import re
import statistics
from typing import Set

# Create a logger
logging.basicConfig(format="%(name)s - %(asctime)s %(levelname)s: %(message)s")
logger = logging.getLogger("fasta_gtf_filter")
logger.setLevel(logging.INFO)

def extract_fasta_seq_names(fasta_name: str) -> Set[str]:
    """Extracts the sequence names from a FASTA file."""
    with open(fasta_name) as fasta:
        return {line[1:].split(None, 1)[0] for line in fasta if line.startswith(">")}

def tab_delimited(file: str) -> float:
    """Check if file is tab-delimited and return median number of tabs."""
    with open(file, "r") as f:
        data = f.read(1024)
        return statistics.median(line.count("\t") for line in data.split("\n"))

def filter_gtf(fasta: str, gtf_in: str, gtf_in_genome_out: str, gtf_transcript_out: str,  skip_transcript_id_check: bool) -> None:
    """Filter GTF file based on FASTA sequence names."""
    if tab_delimited(gtf_in) != 8:
        raise ValueError("Invalid GTF file: Expected 8 tab-separated columns.")

    seq_names_in_genome = extract_fasta_seq_names(fasta)
    logger.info(f"Extracted chromosome sequence names from {fasta}")
    logger.debug("All sequence IDs from FASTA: " + ", ".join(sorted(seq_names_in_genome)))

    seq_names_in_gtf = set()
    try:
        with open(gtf_in) as gtf, open(gtf_in_genome_out, "w") as out, open(gtf_transcript_out, "w") as out2:
            line_count_all, line_count_transcript = 0, 0
            for line in gtf:
                seq_name = line.split("\t")[0]
                seq_names_in_gtf.add(seq_name)  # Add sequence name to the set

                if seq_name in seq_names_in_genome:
                    out.write(line)
                    line_count_all += 1

                    if not skip_transcript_id_check and re.search(r'transcript_id "([^"]+)"', line):
                        with open(gtf_transcript_out, "a") as out2:
                            out2.write(line)
                        line_count_transcript += 1

            if line_count_all == 0:
                raise ValueError("No overlapping scaffolds found.")

            if not skip_transcript_id_check and line_count_transcript == 0:
                raise ValueError("No transcript_id values found in the GTF file.")

    except IOError as e:
        logger.error(f"File operation failed: {e}")
        return

    logger.debug("All sequence IDs from GTF: " + ", ".join(sorted(seq_names_in_gtf)))
    logger.info(f"Extracted {line_count_all} matching sequences from {gtf_in} into {gtf_in_genome_out}")
    logger.info(f"Wrote {line_count_transcript} lines with transcript IDs to {gtf_transcript_out}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Filters a GTF file based on sequence names in a FASTA file.")
    parser.add_argument("--gtf", type=str, required=True, help="GTF file")
    parser.add_argument("--fasta", type=str, required=True, help="Genome fasta file")
    parser.add_argument("--prefix", dest="prefix", default="genes", type=str, help="Prefix for output GTF files")
    parser.add_argument("--skip_transcript_id_check", action='store_true', help="Skip checking for transcript IDs in the GTF file")

    args = parser.parse_args()
    filter_gtf(args.fasta, args.gtf, args.prefix + "_in_genome.gtf", args.prefix + "_with_transcript_ids.gtf", args.skip_transcript_id_check)

