process BWAMEM2_PREMAP {
    tag "$meta.id"
    label 'process_medium'

    // Note: the versions here need to match the versions used in the mulled container below and minimap2/index
    conda "${moduleDir}/../../nf-core/bwamem2/index/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-e5d375990341c5aef3c9aff74f96f66f65375ef6:c5b8c4b7735290369693e2b63cfc1ea0732fde07-0' :
        'biocontainers/mulled-v2-e5d375990341c5aef3c9aff74f96f66f65375ef6:c5b8c4b7735290369693e2b63cfc1ea0732fde07-0' }"

    input:
    tuple val(meta), path(reads)
    tuple val(meta2), path(reference)
  
    output:
    tuple val(meta), path("*.fq.gz"), emit: unmapped_reads
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    // pre-mapping parameters
    def premp_args = task.ext.premap_args ?: ''
    def fastq_in = meta.single_end ? "${reads}" : "${reads[0]} ${reads[1]}"

    // filtering parameters
    def filtering_args = task.ext.filtering_args
    def fastq_out = meta.single_end ? "-0 ${prefix}.fq.gz" : "-s ${prefix}_singletons.fq.gz -0 ${prefix}_broken.fq.gz -1 ${prefix}_1.fq.gz -2 ${prefix}_2.fq.gz"
    """
    # Automatically determine the index prefix
    INDEX="${reference}/*.pac"
    INDEX=( \$INDEX )
    INDEX=\$(basename \${INDEX[0]} .pac)
    INDEX="${reference}/\${INDEX}"

    # Map to the library -> select potentially unmapped reads -> collate -> turn into correct fastq files
    bwa-mem2 mem -t $task.cpus ${premp_args} \${INDEX} ${fastq_in} | \\
    samtools view -@ $task.cpus ${filtering_args} - | \\
    samtools collate -@ $task.cpus -O -r 100000 - collate-tmp | \\
    samtools fastq -@ $task.cpus -n ${fastq_out} -

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwamem2: \$(echo \$(bwa-mem2 version 2>&1) | sed 's/.* //')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
