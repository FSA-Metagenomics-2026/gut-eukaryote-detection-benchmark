
nextflow.enable.dsl = 2

params.fasta_dir     = null
params.out_dir       = './results'
params.target_depth  = 5
params.read_length   = 150
params.cpus          = 8
params.include_human = false

params.host_fasta = '/pub58/sam/refs/Homo_sapiens/GRCh38/NCBI/GCF_000001405.40_GRCh38.p14_genomic.fna'

params.hostile_env = '/pub58/sam/envs/chos11/hostile'
params.hocort_env  = '/pub58/sam/envs/chos11/hocort'

// ISS must be available in the execution PATH.

process calculate_coverage_requirements {
    tag "${sid}"

    input:
    tuple val(sid), path(fasta)
    val(read_length)
    val(target_depth)

    output:
    tuple val(sid), path(fasta), stdout, emit: counts

    script:
    """
    awk -v len=${read_length} -v depth=${target_depth} '
        !/^>/ { bp += length(\$0) }
        END {
            if (bp == 0 || len <= 0 || depth <= 0) exit 1
            pairs = int(bp * depth / (2 * len))
            if (pairs * 2 * len < bp * depth) pairs++
            printf "%.0f\\n", pairs * 2
        }
    ' ${fasta}
    """
}

process simulate_reads {
    tag "${sid}"

    cpus params.cpus
    publishDir "${params.out_dir}/reads", mode: 'symlink'

    input:
    tuple val(sid), path(fasta), val(n_reads)

    output:
    tuple val(sid),
          path("${sid}_R1.fastq.gz"),
          path("${sid}_R2.fastq.gz"),
          emit: reads

    path "${sid}_abundance.txt", emit: abundance

    script:
    """
    awk -v prefix="${sid}" '
        /^>/ { sub(/^>/, ">" prefix "_") }
        { print }
    ' ${fasta} > ${sid}_prefixed.fna

    iss generate \
        --draft ${sid}_prefixed.fna \
        --model novaseq \
        --n_reads ${n_reads} \
        --cpus ${task.cpus} \
        --seed 42 \
        --compress \
        --output ${sid}
    """
}

process merge_reads {
    publishDir "${params.out_dir}/merged", mode: 'symlink'

    input:
    tuple path(r1_files), path(r2_files)

    output:
    tuple path("mixed_R1.fastq.gz"),
          path("mixed_R2.fastq.gz"),
          emit: merged

    script:
    def r1args = r1_files.join(' ')
    def r2args = r2_files.join(' ')

    """
    cat ${r1args} > mixed_R1.fastq.gz &
    pid1=\$!

    cat ${r2args} > mixed_R2.fastq.gz &
    pid2=\$!

    wait \$pid1
    wait \$pid2
    """
}

process build_human_index {
    tag "GRCh38"

    cpus 192
    memory '32 GB'
    conda params.hocort_env

    input:
    path(host_fasta)

    output:
    path("human_index"), emit: index

    script:
    """
    mkdir -p human_index

    bowtie2-build \
        --threads ${task.cpus} \
        ${host_fasta} \
        human_index/GRCh38 \
        > bowtie2_build.log 2>&1
    """
}

process build_hisat_index {
    tag "GRCh38"

    cpus params.cpus
    memory '32 GB'
    conda params.hocort_env

    input:
    path(host_fasta)

    output:
    path("hisat_index"), emit: index

    script:
    """
    mkdir -p hisat_index

    hisat2-build \
        -p ${task.cpus} \
        ${host_fasta} \
        hisat_index/GRCh38
    """
}

process run_hostile {
    tag "Hostile"

    cpus params.cpus
    conda params.hostile_env

    publishDir "${params.out_dir}/hostile", mode: 'symlink'

    input:
    tuple path(r1), path(r2)
    path(index_dir)

    output:
    path("host_negative"), emit: negative
    path("host_positive"), emit: positive
    path("hostile_negative.json"), emit: negative_log
    path("hostile_positive.json"), emit: positive_log

    script:
    """
    mkdir -p host_negative host_positive

    hostile clean \
        --fastq1 ${r1} \
        --fastq2 ${r2} \
        --aligner bowtie2 \
        --index ${index_dir}/GRCh38 \
        --threads ${task.cpus} \
        --output host_negative \
        > hostile_negative.json &
    pid1=\$!

    hostile clean \
        --fastq1 ${r1} \
        --fastq2 ${r2} \
        --aligner bowtie2 \
        --index ${index_dir}/GRCh38 \
        --threads ${task.cpus} \
        --invert \
        --output host_positive \
        > hostile_positive.json &
    pid2=\$!
    wait \$pid1
    wait \$pid2
    """
}

process run_hocort_hisat2 {
    tag "HoCoRT HISAT2"

    cpus params.cpus
    conda params.hocort_env

    publishDir "${params.out_dir}/hocort_hisat2", mode: 'symlink'

    input:
    tuple path(r1), path(r2)
    path(index_dir)

    output:
    tuple path("hocort_negative_R1.fastq.gz"),
          path("hocort_negative_R2.fastq.gz"),
          emit: negative

    script:
    """
    hocort map hisat2 \
        -x ${index_dir}/GRCh38 \
        -i ${r1} ${r2} \
        -o hocort_negative_R1.fastq.gz hocort_negative_R2.fastq.gz \
        --filter true \
        --threads ${task.cpus}
    """
}

workflow {

    if (!params.fasta_dir) {
        error "Please specify --fasta_dir"
    }

    ch_genomes = Channel
        .fromPath(
            "${params.fasta_dir}/*.{fna,fa,fasta}",
            checkIfExists: true
        )
        .map { fasta ->
            tuple(fasta.baseName, fasta)
        }

    if (params.include_human) {
        ch_genomes = ch_genomes.mix(
            Channel.of(
                tuple('Homo_sapiens', file(params.host_fasta))
            )
        )
    }

    ch_counts = calculate_coverage_requirements(
        ch_genomes,
        params.read_length,
        params.target_depth
    ).counts.map { sid, fasta, n_reads ->
        tuple(sid, fasta, n_reads.trim().toLong())
    }

    ch_counts.view { sid, fasta, n_reads ->
        "${sid}: ${n_reads} reads (${n_reads.intdiv(2)} pairs)"
    }

    ch_simulated = simulate_reads(ch_counts).reads

    ch_to_merge = ch_simulated
        .collect(flat: false)
        .map { rows ->
            def sorted = rows.sort { a, b -> a[0] <=> b[0] }
            tuple(
                sorted.collect { it[1] },
                sorted.collect { it[2] }
            )
        }
    

    ch_merged = merge_reads(ch_to_merge).merged

    ch_index = build_human_index(
        Channel.value(file(params.host_fasta))
    ).index

    run_hostile(ch_merged, ch_index)
    

    ch_hisat_index = build_hisat_index(
        Channel.value(file(params.host_fasta))
    ).index

    run_hocort_hisat2(ch_merged, ch_hisat_index)
}
