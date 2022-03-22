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

params.orthofinder_exe = ''
params.dir = ''
params.ref_destination = ''
params.query_destination = ''
params.taxon_selector_exe = ''
params.ncbi_taxonomy_url = ''

/**
*@input takes list of directories containing fasta files
*@output list of copied fasta files in new destination
*/
process orthoFinderFactory {

    label 'slurm_default'

    publishDir "$params.ref_destination"

    input:
    val x

    output:
    val x

    shell:
    """
    rsync -Lavz ${params.dir}/${x} ${params.ref_destination}/
    """
}

/**
*@input takes list of directories containing fasta files
*/
process runOrthoFinder {

    label 'rc_64Gb_32C'

    input:
    val x

    shell:
    """
    ${params.orthofinder_exe} -t 32 -a 8 -f ${params.ref_destination}/${x}
    """
}

/**
*@input takes a valid ncbi taxonomy species name
*@output json formatted file metadata.json containing metadata about species
*/
process queryFactory {

    label 'lsf_default'

    input:
    val x

    output:
    file 'metadata.json'

    shell:
    """
    curl -X GET --header 'Accept: application/json' 'http://test.datafile.production.ensembl.org/search?file_format=fasta&ens_releases[]=99&species[]=${x}' > metadata.json
    """
}

/**
*@input takes a taxon_name, requires params.ncbi_taxonomy_url and params.ref_destination
*@output path of new directory containing query and reference fasta files
*/
process queryTaxonSelectionFactory {

    label 'lsf_default'

    input:
    val x

    output:
    path out_dir

    shell:
    """
    python ${params.taxon_selector_exe} \
        --taxon_name ${x} \
        --url ${params.ncbi_taxonomy_url} \
        --ref_base_dir ${params.ref_destination} \
    """
}

/**
*@input takes a taxon_name, genome fasta file and reference directory
*@output path of new directory containing query and reference fasta files
*/
process mergeRefToQuery {

    label 'lsf_default'

    publishDir "${params.short_term_bucket}/${query}", mode:'copy'

    input:
    val query
    path query_fasta
    path ref_dir

    output:
    path "${params.short_term_bucket}/${query}"

    when:
    // Include conditional on file age

    shell:
    """
    mkdir ${query};
    rsync -Lavz ${ref_dir} ${query}/;
    cp ${query_fasta} ${params.short_term_bucket}/${query};
    """
}

/**
*@input takes path of directory of fasta and precomputed orthofinder results
*@output path of results
*/
process updateOrthofinderRun {

    label 'rc_64Gb_32C'

    publishDir "${params.short_term_bucket}/${x}", mode:'copy'

    input:
    val x

    output:
    val x

    shell:
    """
    ${params.orthofinder_exe} \
    -t 32 -a 8 \
    -b \$(find ${params.query_destination}/${x}/OrthoFinder -maxdepth 1 -mindepth 1 -type d) \
    -f ${params.short_term_bucket}/${x}
    """
}
