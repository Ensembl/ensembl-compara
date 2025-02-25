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
params.ref_destination_farm = ''
params.ref_destination_cloud = ''
params.query_destination = ''
params.taxon_selector_exe = ''
params.ncbi_taxonomy_url = ''
params.output_path = ''
params.embassy = false

/**
*@input takes list of directories containing fasta files
*@output list of copied fasta files in new destination
*/
process orthoFinderFactory {

    publishDir "${params.ref_destination_cloud}/", mode: 'copy', overwrite: 'true'

    input:
    val x

    output:
    path "${x}/"

    shell:
    """
    rsync -Lavz ${params.dir}/${x}/ ${x}
    """

    stub:
    """
    mkdir -p ${params.dir}/${x}
    echo "hello" > ${params.dir}/${x}/test.txt
    """

}

/**
*@input takes list of directories containing fasta files
*/
process runOrthoFinder {

    label 'slurm_64Gb_32C'

    scratch true

    publishDir "${params.ref_destination_cloud}/${x}", mode: 'copy', overwrite: 'true'

    input:
    path x

    shell:
    """
    ${params.orthofinder_exe} -t 32 -a 8 -f ${x}
    """

    stub:
    """
    echo 'Orthofinder on references complete!'
    """
}

// todo: queryFactory to use rest DataFile API to collect metadata json_string
/**
*@input takes a valid ncbi taxonomy species name
*@output json formatted file metadata.json containing metadata about species
*/
// process queryFactory {
//
//     input:
//     val x
//
//     output:
//     stdout
//
//     shell:
//     """
//     curl -X GET --header 'Accept: application/json' 'http://test.datafile.production.ensembl.org/search?file_format=fasta&ens_releases[]=99&species[]=${x}'
//     """
// }

/**
*@input takes a genome fasta file or fasta.gz file
*@output path of uncompressed fasta file
*/
process processGenomeFasta {

    input:
    path x

    output:
    path y

    script:
    y = file(x).getBaseName()
    """
    gunzip -c ${x} > ${y}
    """

    stub:
    y = file(x).getBaseName()
    """
    echo '>gene1\nMAPSQRP' > ${y}
    """
}

/**
*@input takes a taxon_name, requires params.ncbi_taxonomy_url and params.ref_destination_farm
*@output path of appropriate reference collection directory
*/
process queryTaxonSelectionFactory {

    input:
    val x

    output:
    stdout

    script:
    """
    python ${params.taxon_selector_exe} \
        --taxon_name ${x} \
        --url ${params.ncbi_taxonomy_url} \
        --ref_base_dir ${params.ref_destination_farm} \
    """

}

/**
*@input takes a taxon_name, genome fasta file and reference directory
*@output path of new directory containing query and reference fasta files
*/
process mergeRefToQuery {

    publishDir "${params.query_destination}/${query}", mode: 'copy'

    input:
    val query
    path query_fasta
    val ref_dir

    output:
    path "${query}/"

    shell:
    """
    rsync -Lavz ${ref_dir}/ ${query};
    cp ${query_fasta} ${query}/;
    """

    stub:
    """
    mkdir ${query}
    echo '>${query}\nMAPSQRP' > ${query}.fasta
    """
}

/**
*@input takes path of directory of fasta and precomputed orthofinder results
*@output same as input
*/
process triggerUpdateOrthofinderNF {

    input:
    val x

    output:
    stdout

    shell:
    if ( params.embassy ) {
        """
        ssh ${USER}@45.88.81.155 \
        ' nextflow run  ensembl-compara/pipelines/OrthofinderOnQuery/orthofinder_part.nf \
        --orthodir ${x} '
        STDOUT=\$( ssh ${USER}@45.88.81.155 ' echo "Orthofinder update complete on " & hostname ' )
        echo \$STDOUT
        """
    } else {
        """
        nextflow run  ensembl-compara/pipelines/OrthofinderOnQuery/orthofinder_part.nf --orthodir ${x}
        """
    }

    stub:
    if ( params.embassy ) {
        """
        STDOUT=\$(ssh ${USER}@45.88.81.155 ' echo -n ${x} ' )
        echo -n \$STDOUT
        """
    } else {
        """
        echo ${x}
        """
    }
}

/**
*@input takes path of directory of fasta and precomputed orthofinder results
*@output path of results
*/
process updateOrthofinderRun {

    input:
    val x

    output:
    path x, emit: "out_dir"
    stdout emit "debug"

    shell:
    """
    ${params.orthofinder_exe} \
    -t 32 -a 8 \
    -b \$(find ${x}/OrthoFinder -maxdepth 1 -mindepth 1 -type d) \
    -f ${x}
    """

    stub:
    """
    echo ${x}/OrthoFinder
    """
}

/**
*@input takes path of directory of computed orthofinder results
*@output Publishable results directory for example FTP
*/
// process copyToFTP {
// 
//     publishDir "${params.output_path}${x}", mode: 'copy'
// 
//     input:
//     path x
// 
//     output:
//     val "${params.output_path}/${x}"
// 
//     shell:
//     """
//     #datamover
//     """
// 
//     stub:
//     """
//     ls ${params.output_path}/${x}
//     """
// }
