process PREMAP_STAR {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::star=2.7.10a bioconda::samtools=1.16.1 conda-forge::gawk=5.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:1df389393721fc66f3fd8778ad938ac711951107-0' :
        'biocontainers/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:1df389393721fc66f3fd8778ad938ac711951107-0' }"

    input:
    tuple val(meta), path(reads, stageAs: "input*/*")
    path(reference)
    path(exclude)

    output:
    tuple val(meta), path('*.pre-mapped.fq.gz')            , emit: premapped_reads
    tuple val(meta), path('*_pre-mapped.singletons.fq.gz') , emit: premapped_signleton_reads
    tuple val(meta), path('*_pre-mapped.broken.fq.gz')     , emit: premapped_broken_reads
    tuple val(meta), path('*.excluded.fq.gz')              , emit: excluded_reads
    tuple val(meta), path('*_excluded.singletons.fq.gz')   , emit: excluded_signleton_reads
    tuple val(meta), path('*_excluded.broken.fq.gz')       , emit: excluded_broken_reads
    path  "versions.yml"                                   , emit: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // pre-mapping parameters
    def premap_args = task.ext.premap_args

    def reads1 = [], reads2 = []
    meta.single_end ? [reads].flatten().each{reads1 << it} : reads.eachWithIndex{ v, ix -> ( ix & 1 ? reads2 : reads1) << v }

    // filtering parameters
    def fastq_out_primary = "", fastq_out_excluded = ""

    if (meta.single_end) {
        fastq_out_primary = "-0 ${prefix}.pre-mapped.fq.gz"
        fastq_out_excluded = "-0 ${prefix}.excluded.fq.gz"
    } else {
        fastq_out_primary = "-s ${prefix}_pre-mapped.singletons.fq.gz -0 ${prefix}_pre-mapped.broken.fq.gz -1 ${prefix}_1.pre-mapped.fq.gz -2 ${prefix}_2.pre-mapped.fq.gz"
        fastq_out_excluded = "-s ${prefix}_excluded.singletons.fq.gz -0 ${prefix}_excluded.broken.fq.gz -1 ${prefix}_1.excluded.fq.gz -2 ${prefix}_2.excluded.fq.gz"
    }
    """
    # Map to the library -> separate reads mapped to exclude regions -> collate -> turn into correct fastq files
    STAR \\
        --genomeDir $reference \\
        --readFilesIn ${reads1.join(",")} ${reads2.join(",")} \\
        --runThreadN $task.cpus \\
        --outFileNamePrefix ${prefix}. \\
        $premap_args
    
    samtools view -@ $task.cpus -b -h --output ${prefix}.excluded.bam --output-unselected /dev/stdout -L $exclude ${prefix}.Aligned.out.bam | \\
    samtools collate -@ $task.cpus -O -r 100000 - collate-tmp | \\
    samtools fastq -@ $task.cpus -n ${fastq_out_primary} -

    rm ${prefix}.Aligned.out.bam

    if [ -f ${prefix}.Unmapped.out.mate1 ]; then
        cat ${prefix}.Unmapped.out.mate1 | bgzip -@ $task.cpus --stdout >> ${prefix}_1.pre-mapped.fq.gz
    fi
    if [ -f ${prefix}.Unmapped.out.mate2 ]; then
        cat ${prefix}.Unmapped.out.mate2 | bgzip -@ $task.cpus --stdout >> ${prefix}_2.pre-mapped.fq.gz
    fi

    # Collate and fastq the excluded reads
    samtools collate -@ $task.cpus -O -r 100000 ${prefix}.excluded.bam collate-tmp | \\
    samtools fastq -@ $task.cpus -n ${fastq_out_excluded} -

    rm ${prefix}.excluded.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$(STAR --version | sed -e "s/STAR_//g")
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        gawk: \$(echo \$(gawk --version 2>&1) | sed 's/^.*GNU Awk //; s/, .*\$//')
    END_VERSIONS
    """
}
