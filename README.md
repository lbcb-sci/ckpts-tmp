# RNA-seq Workflow

This project aims to build a simple, reproducible RNA-seq processing workflow.

## Task

Process raw RNA-seq sequencing reads into quality-controlled, analysis-ready gene-level count data, with summary quality-control information produced alongside the results.

## Constraints

- The workflow should be reproducible.
- It should support typical RNA-seq input data.
- It should produce gene-level count data suitable for downstream analysis.
- Quality-control information should be generated and summarized.
- The workflow should remain reasonably simple and suitable for local execution.
- Differential expression analysis is outside the scope of the initial version.

## Test data

`data/fastq/SRR6357070_{1,2}.fastq.gz` is a small paired-end *S. cerevisiae* RNA-seq
sample (50,000 read pairs, ~4.3MB total) used to build and exercise a first, simple
version of the workflow. It's the `WT_REP1` sample from nf-core's official
[rnaseq test dataset](https://github.com/nf-core/test-datasets/tree/rnaseq/testdata/GSE110004)
(original source: GEO [GSE110004](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE110004)).

The files are checked into the repo (small enough at 4.3MB) so the workflow is
reproducible without a network dependency. To re-fetch them if needed:

```bash
mkdir -p data/fastq
curl -sL -o data/fastq/SRR6357070_1.fastq.gz "https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/testdata/GSE110004/SRR6357070_1.fastq.gz"
curl -sL -o data/fastq/SRR6357070_2.fastq.gz "https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/testdata/GSE110004/SRR6357070_2.fastq.gz"
```
