process MINIMAP2_PREMAP {
    tag "$meta.id"
    label 'process_medium'

    // Note: the versions here need to match the versions used in the mulled container below and minimap2/index
    conda "${moduleDir}/../../nf-core/minimap2/index/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-66534bcbb7031a148b13e2ad42583020b9cd25c4:365b17b986c1a60c1b82c6066a9345f38317b763-0' :
        'biocontainers/mulled-v2-66534bcbb7031a148b13e2ad42583020b9cd25c4:365b17b986c1a60c1b82c6066a9345f38317b763-0' }"

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
    def premp_args = task.ext.premap_args
    def fastq_in = meta.single_end ? "${reads}" : "${reads[0]} ${reads[1]}"

    // filtering parameters
    def filtering_args = task.ext.filtering_args
    def fastq_out = meta.single_end ? "-o ${prefix}.fq.gz" : "-s ${prefix}_singletons.fq.gz -0 ${prefix}_broken.fq.gz -1 ${prefix}_1.fq.gz -2 ${prefix}_2.fq.gz"
    """
    # Map to the library -> select potentially unmapped reads -> collate -> turn into correct fastq files
    minimap2 ${premp_args} -t $task.cpus ${reference} ${fastq_in} | \\
    samtools view -@ $task.cpus ${filtering_args} - | \\
    samtools collate -T collate-tmp -@ $task.cpus -O -r 100000 - | \\
    samtools fastq -@ $task.cpus -n ${fastq_out} -

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version 2>&1)
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
