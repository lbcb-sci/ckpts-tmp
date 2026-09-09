configfile: "config.yaml"

SAMPLES = list(config["samples"].keys())


rule all:
    input:
        "results/counts/gene_counts.csv",
        "results/qc/multiqc_report.html",


rule fastqc_raw:
    input:
        r1=lambda wc: config["samples"][wc.sample]["r1"],
        r2=lambda wc: config["samples"][wc.sample]["r2"],
    output:
        directory("results/qc/fastqc_raw/{sample}"),
    log:
        "logs/fastqc_raw/{sample}.log",
    shell:
        "mkdir -p {output} && fastqc --outdir {output} {input.r1} {input.r2} > {log} 2>&1"


rule fastp:
    input:
        r1=lambda wc: config["samples"][wc.sample]["r1"],
        r2=lambda wc: config["samples"][wc.sample]["r2"],
    output:
        r1="results/trimmed/{sample}_1.fastq.gz",
        r2="results/trimmed/{sample}_2.fastq.gz",
        json="results/qc/fastp/{sample}.json",
        html="results/qc/fastp/{sample}.html",
    log:
        "logs/fastp/{sample}.log",
    threads: 4
    shell:
        "fastp -i {input.r1} -I {input.r2} -o {output.r1} -O {output.r2} "
        "-j {output.json} -h {output.html} -w {threads} > {log} 2>&1"


rule salmon_index:
    input:
        fasta=config["reference"]["transcriptome_fasta"],
    output:
        directory("results/salmon_index"),
    log:
        "logs/salmon_index.log",
    threads: 4
    shell:
        "salmon index -t {input.fasta} -i {output} -p {threads} > {log} 2>&1"


rule salmon_quant:
    input:
        r1="results/trimmed/{sample}_1.fastq.gz",
        r2="results/trimmed/{sample}_2.fastq.gz",
        index="results/salmon_index",
    output:
        "results/salmon/{sample}/quant.sf",
    params:
        outdir=lambda wc: f"results/salmon/{wc.sample}",
    log:
        "logs/salmon_quant/{sample}.log",
    threads: 4
    shell:
        "salmon quant -i {input.index} -l A -1 {input.r1} -2 {input.r2} "
        "-p {threads} -o {params.outdir} > {log} 2>&1"


rule tx2gene:
    input:
        gtf=config["reference"]["gtf"],
    output:
        "results/tx2gene.tsv",
    log:
        "logs/tx2gene.log",
    shell:
        "pytximport create-map -i {input.gtf} -o {output} -ow > {log} 2>&1"


rule gene_counts:
    input:
        quant=expand("results/salmon/{sample}/quant.sf", sample=SAMPLES),
        map="results/tx2gene.tsv",
    output:
        "results/counts/gene_counts.csv",
    params:
        inputs=lambda wc, input: " ".join(f"-i {q}" for q in input.quant),
    log:
        "logs/gene_counts.log",
    shell:
        "pytximport run {params.inputs} -t salmon -m {input.map} "
        "-o {output} -of csv -ow > {log} 2>&1"


rule multiqc:
    input:
        expand("results/qc/fastqc_raw/{sample}", sample=SAMPLES),
        expand("results/qc/fastp/{sample}.json", sample=SAMPLES),
        expand("results/salmon/{sample}/quant.sf", sample=SAMPLES),
    output:
        "results/qc/multiqc_report.html",
    log:
        "logs/multiqc.log",
    shell:
        "multiqc results/qc results/salmon --outdir results/qc "
        "--filename multiqc_report.html --force > {log} 2>&1"
