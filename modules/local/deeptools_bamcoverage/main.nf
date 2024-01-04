process DEEPTOOLS_BAMCOVERAGE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-eb9e7907c7a753917c1e4d7a64384c047429618a:62d1ebe2d3a2a9d1a7ad31e0b902983fa7c25fa7-0':
        'biocontainers/mulled-v2-eb9e7907c7a753917c1e4d7a64384c047429618a:62d1ebe2d3a2a9d1a7ad31e0b902983fa7c25fa7-0' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.forward.bigWig")   , emit: bigwig_forward
    tuple val(meta), path("*.reverse.bigWig")   , emit: bigwig_reverse
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def prefix_forward = "${prefix}.forward"
    def prefix_reverse = "${prefix}.reverse"
    if (meta.strandedness == 'forward') {
        prefix_forward = "${prefix}.reverse"
        prefix_reverse = "${prefix}.forward"
    }
    """
    bamCoverage \\
        --bam $bam \\
        $args \\
        --numberOfProcessors ${task.cpus} \\
        --outFileName ${prefix_forward}.bigWig \\
        --filterRNAstrand forward

    bamCoverage \\
        --bam $bam \\
        $args \\
        --numberOfProcessors ${task.cpus} \\
        --outFileName ${prefix_reverse}.bigWig \\
        --filterRNAstrand reverse

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        deeptools: \$(bamCoverage --version | sed -e "s/bamCoverage //g")
    END_VERSIONS
    """
}
