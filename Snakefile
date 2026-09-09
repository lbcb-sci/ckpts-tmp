# No default configfile: always pass one explicitly, e.g.
#   snakemake --configfile config.test.yaml --cores 4
# A default here would get merged (not replaced) with whatever --configfile is
# passed, silently unioning both configs' "samples" dicts.

RESULTS = config["results_dir"]

SAMPLES = list(config["samples"].keys())
PE_SAMPLES = [s for s in SAMPLES if config["samples"][s].get("r2")]
SE_SAMPLES = [s for s in SAMPLES if s not in PE_SAMPLES]

# Regex alternation used to route each sample to its paired-end/single-end rule
# variant. "(?!)" never matches, so an empty list doesn't turn into a
# constraint that matches everything.
PE_PATTERN = "|".join(PE_SAMPLES) if PE_SAMPLES else "(?!)"
SE_PATTERN = "|".join(SE_SAMPLES) if SE_SAMPLES else "(?!)"


rule all:
    input:
        f"{RESULTS}/counts/gene_counts.csv",
        f"{RESULTS}/qc/multiqc_report.html",


def fastqc_raw_input(wc):
    sample = config["samples"][wc.sample]
    files = [sample["r1"]]
    if sample.get("r2"):
        files.append(sample["r2"])
    return files


rule fastqc_raw:
    input:
        fastqc_raw_input,
    output:
        directory(f"{RESULTS}/qc/fastqc_raw/{{sample}}"),
    log:
        "logs/fastqc_raw/{sample}.log",
    shell:
        "mkdir -p {output} && fastqc --outdir {output} {input} > {log} 2>&1"


rule fastp_pe:
    input:
        r1=lambda wc: config["samples"][wc.sample]["r1"],
        r2=lambda wc: config["samples"][wc.sample]["r2"],
    output:
        r1=f"{RESULTS}/trimmed/{{sample}}_1.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_2.fastq.gz",
        json=f"{RESULTS}/qc/fastp/{{sample}}.json",
        html=f"{RESULTS}/qc/fastp/{{sample}}.html",
    log:
        "logs/fastp/{sample}.log",
    threads: 4
    wildcard_constraints:
        sample=PE_PATTERN,
    shell:
        "fastp -i {input.r1} -I {input.r2} -o {output.r1} -O {output.r2} "
        "-j {output.json} -h {output.html} -w {threads} > {log} 2>&1"


rule fastp_se:
    input:
        r1=lambda wc: config["samples"][wc.sample]["r1"],
    output:
        r1=f"{RESULTS}/trimmed/{{sample}}.fastq.gz",
        json=f"{RESULTS}/qc/fastp/{{sample}}.json",
        html=f"{RESULTS}/qc/fastp/{{sample}}.html",
    log:
        "logs/fastp/{sample}.log",
    threads: 4
    wildcard_constraints:
        sample=SE_PATTERN,
    shell:
        "fastp -i {input.r1} -o {output.r1} "
        "-j {output.json} -h {output.html} -w {threads} > {log} 2>&1"


rule salmon_index:
    input:
        fasta=config["reference"]["transcriptome_fasta"],
    output:
        directory(f"{RESULTS}/salmon_index"),
    log:
        "logs/salmon_index.log",
    threads: 4
    shell:
        "salmon index -t {input.fasta} -i {output} -p {threads} > {log} 2>&1"


rule salmon_quant_pe:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}_1.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_2.fastq.gz",
        index=f"{RESULTS}/salmon_index",
    output:
        f"{RESULTS}/salmon/{{sample}}/quant.sf",
    params:
        outdir=lambda wc: f"{RESULTS}/salmon/{wc.sample}",
    log:
        "logs/salmon_quant/{sample}.log",
    threads: 4
    wildcard_constraints:
        sample=PE_PATTERN,
    shell:
        "salmon quant -i {input.index} -l A -1 {input.r1} -2 {input.r2} "
        "-p {threads} -o {params.outdir} > {log} 2>&1"


rule salmon_quant_se:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}.fastq.gz",
        index=f"{RESULTS}/salmon_index",
    output:
        f"{RESULTS}/salmon/{{sample}}/quant.sf",
    params:
        outdir=lambda wc: f"{RESULTS}/salmon/{wc.sample}",
    log:
        "logs/salmon_quant/{sample}.log",
    threads: 4
    wildcard_constraints:
        sample=SE_PATTERN,
    shell:
        "salmon quant -i {input.index} -l A -r {input.r1} "
        "-p {threads} -o {params.outdir} > {log} 2>&1"


rule tx2gene:
    # Assumes a standard GTF with `transcript_id`/`gene_id` attributes (e.g. Ensembl-style).
    # A GFF3 (`ID`/`Parent`-style) or nonstandard GTF would need
    # `--source-field`/`--target-field` passed to `pytximport create-map`.
    input:
        gtf=config["reference"]["gtf"],
    output:
        f"{RESULTS}/tx2gene.tsv",
    log:
        "logs/tx2gene.log",
    shell:
        "pytximport create-map -i {input.gtf} -o {output} -ow > {log} 2>&1"


rule gene_counts:
    input:
        quant=expand(f"{RESULTS}/salmon/{{sample}}/quant.sf", sample=SAMPLES),
        map=f"{RESULTS}/tx2gene.tsv",
    output:
        f"{RESULTS}/counts/gene_counts.csv",
    params:
        inputs=lambda wc, input: " ".join(f"-i {q}" for q in input.quant),
    log:
        "logs/gene_counts.log",
    shell:
        "pytximport run {params.inputs} -t salmon -m {input.map} "
        "-o {output} -of csv -ow > {log} 2>&1"


rule multiqc:
    input:
        expand(f"{RESULTS}/qc/fastqc_raw/{{sample}}", sample=SAMPLES),
        expand(f"{RESULTS}/qc/fastp/{{sample}}.json", sample=SAMPLES),
        expand(f"{RESULTS}/salmon/{{sample}}/quant.sf", sample=SAMPLES),
    output:
        f"{RESULTS}/qc/multiqc_report.html",
    params:
        results_dir=RESULTS,
    log:
        "logs/multiqc.log",
    shell:
        "multiqc {params.results_dir}/qc {params.results_dir}/salmon "
        "--outdir {params.results_dir}/qc "
        "--filename multiqc_report.html --force > {log} 2>&1"
