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

`test-data/fastq/SRR6357070_{1,2}.fastq.gz` is a small paired-end *S. cerevisiae*
RNA-seq sample (50,000 read pairs, ~4.3MB total) used to build and exercise a first,
simple version of the workflow. It's the `WT_REP1` sample from nf-core's official
[rnaseq test dataset](https://github.com/nf-core/test-datasets/tree/rnaseq/testdata/GSE110004)
(original source: GEO [GSE110004](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE110004)).

`test-data/reference/transcriptome.fasta` and `test-data/reference/genes.gtf` are the
matching transcriptome/annotation fixture from the same nf-core test-datasets repo,
used by Salmon and the gene-counting step. Note: this is fixture data for testing
the workflow, not the reference you'd use for a real analysis.

The gene-counting step (transcript→gene mapping) assumes a standard GTF with
`transcript_id`/`gene_id` attributes (e.g. Ensembl-style), which this fixture GTF
has. A GFF3 or nonstandard GTF may need extra options — see the comment on the
`tx2gene` rule in the `Snakefile`.

This fixture is used by `config.test.yaml`, the config for testing the pipeline
itself. To run against a real dataset, create your own config file (see "Running
the workflow" below) pointing at your own samples and reference — it isn't tied to
the pipeline.

The files are checked into the repo (small enough, ~350KB) so the workflow is
reproducible without a network dependency. To re-fetch them if needed:

```bash
mkdir -p test-data/fastq test-data/reference
curl -sL -o test-data/fastq/SRR6357070_1.fastq.gz "https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/testdata/GSE110004/SRR6357070_1.fastq.gz"
curl -sL -o test-data/fastq/SRR6357070_2.fastq.gz "https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/testdata/GSE110004/SRR6357070_2.fastq.gz"
curl -sL -o test-data/reference/transcriptome.fasta "https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/reference/transcriptome.fasta"
curl -sL -o test-data/reference/genes.gtf "https://raw.githubusercontent.com/nf-core/test-datasets/rnaseq/reference/genes.gtf"
```

## Running the workflow

Set up the environment once:

```bash
conda env create -f environment.yml
conda activate rnaseq-workflow
```

Then run the pipeline, always passing an explicit `--configfile` (there's no
default — see below) and adjusting `--cores` to what's available:

```bash
snakemake --configfile config.test.yaml --cores 4
```

For a real dataset, copy `config.test.yaml` to your own config file and point it at
your samples/reference — give it its own `results_dir` (e.g. `results/<name>/`) so
different runs never mix or overwrite each other's outputs. Within a config's
`results_dir`:

- `counts/gene_counts.csv` — the gene-level count matrix.
- `qc/multiqc_report.html` — aggregated QC (FastQC, fastp, Salmon).

Snakemake merges (rather than replaces) a `--configfile` with any default set via a
`configfile:` directive in the `Snakefile` — which is why there isn't one; passing
`--configfile` is required, and omitting it fails fast with a clear error rather than
silently mixing two configs' samples together.

The pipeline: FastQC (raw QC) → fastp (trimming) → Salmon (pseudo-alignment +
transcript quantification) → pytximport (gene-level summarization) → MultiQC
(QC summary).
