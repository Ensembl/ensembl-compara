#!/usr/bin/env nextflow
/** See the NOTICE file distributed with this work for additional information
* regarding copyright ownership.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

nextflow.enable.dsl=2

include { ensemblLogo } from "./../utilities.nf"
include {
    convertTaskParamTypes;
    composeChainFileName;
    getCommonMapEntries;
    getDefaultHalCachePath;
    getNonemptyChains;
    loadMappingFromTsv;
} from "./utilities.nf"


def helpMessage() {
    log.info ensemblLogo()
    log.info """
    Usage examples:

    * Basic usage:
        \$ nextflow run main.nf --input /path/to/input.tsv --hal /path/to/alignment.hal

    This workflow is based on the document by Mark Diekhans describing generation of pairwise chain files from a HAL alignment.
    ( See https://github.com/ComparativeGenomicsToolkit/hal/blob/f8a457713d7d578464dc17f760583a0128080085/doc/chaining-mapping.md )

    See "nextflow.config" for additional options.

    """.stripIndent()
}

if (params.help) {
    helpMessage()
    exit 0
}

if (!params.input || !params.hal) {
    helpMessage()
    exit 0
}

def hal_cache = params.hal_cache ?: getDefaultHalCachePath(params.hal)


process DUMP_HAL_CHROM_SIZES {

    publishDir "${hal_cache}/genome/chrom_sizes", mode: "copy",  overwrite: false

    input:
    path(hal)

    output:
    path("*.chrom.sizes"), emit: genome_chrom_sizes

    shell:
    '''
    !{params.hal_stats_exe} --genomes !{hal} | tr ' ' '\\n' > hal_genome_names.txt

    while read genome_name
    do !{params.hal_stats_exe} --chromSizes $genome_name !{hal} > "${genome_name}.chrom.sizes"
    done < hal_genome_names.txt
    '''
}

process PREP_TASK_PARAMS {

    input:
    tuple path(task_sheet), path(hal)
    val(chrom_sizes)

    output:
    path "prepped_param_sets.tsv", emit: prepped_param_sets

    script:
    """
    ${params.prep_task_params_exe} $task_sheet $hal ${hal_cache}/genome/chrom_sizes prepped_param_sets.tsv
    """
}

process DUMP_HAL_GENOME_SEQS {

    publishDir "${hal_cache}/genome/2bit", mode: "copy",  overwrite: false

    input:
    val genome_name

    output:
    tuple val(genome_name), path("*.2bit"), emit: genome_dump

    script:
    """
    ${params.hal_to_fasta_exe} ${params.hal} $genome_name | \
        ${params.fasta_to_2bit_exe} stdin "${genome_name}.2bit"
    """
}

process MAKE_SOURCE_BED {

    input:
    val task_params

    output:
    tuple val(task_params), path("liftover_source.bed"), emit: liftover_input

    script:
    """
    #!/usr/bin/env python3
    from pathlib import Path

    from ensembl.compara.utils.hal import make_src_region_file
    from ensembl.compara.utils.ucsc import load_chrom_sizes_file

    chrom_sizes_dir = Path("${hal_cache}") / "genome" / "chrom_sizes"
    chrom_sizes_file = chrom_sizes_dir / "${task_params.source_genome}.chrom.sizes"
    source_chrom_sizes = load_chrom_sizes_file(chrom_sizes_file)

    make_src_region_file(
        "${task_params.source_sequence}",
        ${task_params.source_start},
        ${task_params.source_end},
        ${task_params.source_strand},
        "${task_params.source_genome}",
        source_chrom_sizes,
        "liftover_source.bed",
    )
    """
}

process HAL_LIFTOVER {
    label "rc_1Gb"

    input:
    tuple val(task_params), path(liftover_source_bed)

    output:
    tuple val(task_params), path("liftover.psl"), emit: liftover_psl

    script:
    """
    ${params.hal_liftover_exe} --outPSL ${params.hal} ${task_params.source_genome} \
        $liftover_source_bed ${task_params.dest_genome} liftover.psl
    """
}

process PSL_POS_TARGET {

    input:
    tuple val(task_params), path(liftover_psl)

    output:
    tuple val(task_params), path("pos_target.psl"), emit: pos_target_psl

    script:
    """
    ${params.psl_pos_target_exe} $liftover_psl pos_target.psl
    """
}

process PSL_SWAP {

    input:
    tuple val(task_params), path(pos_target_psl)

    output:
    tuple val(task_params), path("swapped.psl"), emit: swapped_psl

    script:
    """
    ${params.psl_swap_exe} $pos_target_psl swapped.psl
    """
}

process CHAIN_ALN {

    input:
    tuple val(task_params), path(swapped_psl), val(genome_dump_summary)

    output:
    tuple val(task_params), path("*.chain"), emit: chain

    script:
    def twobit_file_map = loadMappingFromTsv(genome_dump_summary)

    // Target for source genome, query for destination genome. It is what it is.
    def target_2bit_file = twobit_file_map[task_params.source_genome]
    def query_2bit_file = twobit_file_map[task_params.dest_genome]

    def chain_file_name = composeChainFileName(task_params, task_params.liftover_level)
    """
    ${params.axt_chain_exe} -psl -linearGap=medium $swapped_psl \
        $target_2bit_file $query_2bit_file $chain_file_name
    """
}

process COMPRESS_CHAIN {

    publishDir "${hal_cache}/${task_params.liftover_level}/chain", mode: "copy",  overwrite: true

    input:
    tuple val(task_params), path(chain_file)

    output:
    tuple val(task_params), path("*.chain.gz"), emit: compressed_chain

    script:
    """
    gzip -c "$chain_file" > "${chain_file}.gz"
    """
}

process MERGE_CHAINS {

    publishDir "${hal_cache}/${task_params.group_level}/chain", mode: "copy",  overwrite: true

    input:
    tuple val(task_params), path(chain_files)

    output:
    path("*.chain.gz"), emit: merged_chain

    script:
    def merged_chain_file_path = composeChainFileName(task_params, task_params.group_level)
    """
    find . -maxdepth 1 -name '*.chain.gz' -exec zcat {} '+' >> "$merged_chain_file_path"
    gzip -c "$merged_chain_file_path" > "${merged_chain_file_path}.gz"
    """
}

workflow {
    println(ensemblLogo())

    channel.value(params.hal) \
        | set { input_hal }

    DUMP_HAL_CHROM_SIZES ( input_hal )

    DUMP_HAL_CHROM_SIZES.out.genome_chrom_sizes \
        | collect
        | set { chrom_sizes }


    channel.value([params.input, params.hal]) \
        | set { input_task_params }

    PREP_TASK_PARAMS ( input_task_params, chrom_sizes )

    PREP_TASK_PARAMS.out.prepped_param_sets \
        | splitCsv(charset: "utf-8", header: true, sep: "\t") \
        | map { convertTaskParamTypes(it) }
        | set { task_param_sets }

    task_param_sets \
        | map { [ it.source_genome, it.dest_genome ] } \
        | flatMap \
        | unique \
        | set { genomes }


    DUMP_HAL_GENOME_SEQS ( genomes )

    DUMP_HAL_GENOME_SEQS.out.genome_dump \
        | map { it*.toString().join("\t") } \
        | collectFile(name: "genome_dump_summary.tsv", newLine: true) \
        | set { genome_dump_summary }


    MAKE_SOURCE_BED ( task_param_sets )

    HAL_LIFTOVER ( MAKE_SOURCE_BED.out.liftover_input )

    PSL_POS_TARGET ( HAL_LIFTOVER.out.liftover_psl )

    PSL_SWAP ( PSL_POS_TARGET.out.pos_target_psl )

    PSL_SWAP.out.swapped_psl \
        | combine(genome_dump_summary) \
        | set { alns_to_chain }


    CHAIN_ALN ( alns_to_chain )

    COMPRESS_CHAIN ( CHAIN_ALN.out.chain )

    COMPRESS_CHAIN.out.compressed_chain \
        | filter { task_params, chain_file -> task_params.containsKey("group_key") } \
        | map {
              task_params, chain_file ->
              tuple( groupKey(task_params.group_key, task_params.group_size), task_params, chain_file )
          } \
        | groupTuple \
        | map { it.tail() } /* group key no longer needed */ \
        | map {
              task_param_sets, chain_files ->
              tuple( getCommonMapEntries(task_param_sets), getNonemptyChains(chain_files) )
          } \
        | filter { task_params, chain_files -> chain_files.size() > 0 } \
        | set { chains_to_merge }

    MERGE_CHAINS ( chains_to_merge )
}

