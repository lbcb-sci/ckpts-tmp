# Simple RNA-seq Workflow (Snakemake + Salmon, first version)

## Context

The README defines the goal: turn raw RNA-seq FASTQ reads into a quality-controlled,
gene-level count matrix, with QC summarized alongside the results. DE analysis is explicitly out of scope. We already have a small paired-end test sample (`data/fastq/SRR6357070_{1,2}.fastq.gz`, yeast, 50k read pairs) checked into the repo.

Decisions made with the user for this revision:
- **Snakemake** for orchestration (dependency-aware, incremental, multi-sample-ready).
- **Salmon** (pseudo-alignment + quantification) instead of a genome aligner +
  featureCounts — simpler (no genome index/BAM sorting step), faster, and standard
  for count-matrix-only workflows that don't need read-level alignment positions.
- **pytximport** to summarize Salmon's transcript-level quantification to the
  gene-level count matrix the README requires.
- **Repo structure fix**: a plain top-level `reference/` folder would wrongly imply
  it holds *the* canonical reference for the workflow. It doesn't — it's just the
  fixture paired with the test FASTQ. Test fixtures (FASTQ + reference) are grouped
  together under one clearly-scoped directory, and the workflow itself treats
  reference/sample paths as config-driven, not hardcoded.

## Repo structure change

Rename `data/` → `test-data/` (git mv, preserves history) and add a reference
subfolder there:

```
test-data/
  fastq/
    SRR6357070_1.fastq.gz
    SRR6357070_2.fastq.gz
  reference/
    transcriptome.fasta   # transcript-level FASTA (Salmon indexes transcripts, not the genome)
    genes.gtf             # used to derive the transcript→gene mapping
```

`config.yaml` (new) is the single place that names which FASTQ/reference paths the
workflow runs against — for now it points at `test-data/`, but nothing in the
`Snakefile` hardcodes that directory, so pointing it at a real dataset later is a
config-only change, not a structural one.

## Reference files

Both come from the same `nf-core/test-datasets` (`rnaseq` branch, `reference/`
folder) that the test FASTQ itself is drawn from, so they're guaranteed to match:
`transcriptome.fasta` (155KB) and `genes.gtf` (204KB). Tiny enough to check into git,
same rationale as the FASTQ (reproducible without a network dependency).

## Tool choices

- **FastQC** — raw-read QC.
- **fastp** — adapter/quality trimming; also emits its own QC report (JSON+HTML).
- **Salmon** — index the transcriptome once, then quantify each sample's trimmed
  reads directly (mapping-based mode, library type auto-detected with `-l A`) →
  per-sample `quant.sf` (transcript-level counts/TPM). No genome alignment, no BAM.
  *Simplification:* a plain (non-decoy-aware) transcriptome index is used for this
  first version — decoy-aware indexing (adding the genome as a decoy) improves
  specificity but needs the genome FASTQ too; noted as a future enhancement, not
  required for a first working version.
- **pytximport** — reads all samples' `quant.sf` + a transcript→gene mapping,
  outputs the gene-level count matrix.
- **MultiQC** — aggregates FastQC, fastp, and Salmon logs into one summary HTML
  report (satisfies the "QC summary" requirement).

All tools installed via one root `environment.yml` (conda/bioconda + pip for
`pytximport`), activated once before running Snakemake — no per-rule conda envs, to
keep this first version simple.

## Files to create

- `environment.yml` — `snakemake-minimal`, `fastqc`, `fastp`, `salmon`, `multiqc`,
  `python`, `pandas`, and `pytximport` (pip).
- `test-data/reference/transcriptome.fasta`, `test-data/reference/genes.gtf` —
  downloaded as described above.
- `config.yaml`:
  ```yaml
  reference:
    transcriptome_fasta: test-data/reference/transcriptome.fasta
    gtf: test-data/reference/genes.gtf
  samples:
    WT_REP1:
      r1: test-data/fastq/SRR6357070_1.fastq.gz
      r2: test-data/fastq/SRR6357070_2.fastq.gz
  ```
- `Snakefile` — rules, all outputs under `results/`:
  1. `fastqc_raw` — FastQC on each raw R1/R2 → `results/qc/fastqc_raw/`
  2. `fastp` — trim `{sample}_{1,2}.fastq.gz` (paths from config) →
     `results/trimmed/{sample}_{1,2}.fastq.gz` +
     `results/qc/fastp/{sample}.{json,html}`
  3. `salmon_index` — build index from `config["reference"]["transcriptome_fasta"]`
     → `results/salmon_index/`
  4. `salmon_quant` — quantify each sample's trimmed reads →
     `results/salmon/{sample}/quant.sf` + Salmon logs (consumed by MultiQC)
  5. `tx2gene` — derive a transcript→gene mapping from
     `config["reference"]["gtf"]` → `results/tx2gene.tsv`
  6. `gene_counts` — pytximport combines all samples' `quant.sf` + `tx2gene.tsv` →
     `results/counts/gene_counts.tsv` (the gene-level count matrix; one column per
     sample, one column for now)
  7. `multiqc` — scans `results/qc/` and `results/salmon/` →
     `results/qc/multiqc_report.html`
  8. `all` (default target) — depends on the count matrix + MultiQC report.
- `.gitignore` (recreated — removed earlier when it only contained the now-committed
  `data/` test fixtures) — covering the artifacts this workflow will generate:
  - `results/` — regenerable pipeline outputs, unlike the small fixed test fixtures,
    which stay committed.
  - `.snakemake/` — Snakemake's internal working/metadata/lock directory.
  - `__pycache__/`, `*.pyc` — Python bytecode (from the `pytximport`/pandas step).

## Files to modify

- `README.md` — update the existing "Test data" section's paths from `data/fastq/`
  to `test-data/fastq/`, mention the new `test-data/reference/` fixture, and add a
  "Running the workflow" section: environment setup
  (`conda env create -f environment.yml`), run command (`snakemake --cores <N>`),
  and output locations (`results/counts/gene_counts.tsv`,
  `results/qc/multiqc_report.html`).

## Verification (this round)

Scope for this round is building the pipeline, creating the conda environment, and a
dry run only — no actual pipeline execution yet; that's deferred to a later, separate
step.

1. `conda env create -f environment.yml` — confirm the environment resolves and
   installs cleanly (catches tool/version/channel issues early).
2. `conda activate <env>` then `snakemake -n` (dry run) — confirm the DAG builds
   with no missing inputs/rules, and shows the expected jobs for the single sample.

Deferred to later (not part of this round): actually running the pipeline
(`snakemake --cores <N>`), sanity-checking `results/counts/gene_counts.tsv` and the
MultiQC report, and re-running to confirm idempotency.
