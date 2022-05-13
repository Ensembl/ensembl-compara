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

include { listSubDirs; ensemblLogo } from './../utilities.nf'

def helpMessage() {
    log.info ensemblLogo()
    log.info """
    Usage:

    """.stripIndent()
}

params.help = ''
if (params.help) {
    helpMessage()
    exit 0
}

if (!params.dir) {
    helpMessage()
    exit 0
}

process prepareBusco {
    input:
        path protfa
    output:
        path "longest_busco_proteins.fas"
    script:
    """
    ${params.scriptsDir}/filter_for_longest_busco.py -i $protfa -o longest_busco_proteins.fas
    """
}

process buscoAnnot {
    label 'rc_64Gb'
    input:
        path busco_prot
        path genome
    output:
        path "cdna_*.fas"
    script:
    """
	mkdir anno_res
	export ENSCODE=$params.enscode
    ln -s `which tblastn` .
	python3 $params.anno_exe --output_dir anno_res --genome_file $genome --num_threads 30 --max_intron_length 100000 --run_busco 1 --busco_protein_file $busco_prot
	GEN=`basename $genome`
	gffread -w cdna_\$GEN -g $genome anno_res/busco_output/annotation.gtf
    """
}

process collateBusco{
	input:
		val cdnas
	script:
	"""
	"""

}

workflow {
        println(ensemblLogo())
        prepareBusco(params.busco_proteins)
        genomes = Channel.fromPath("${params.dir}/*.fas")

        buscoAnnot(prepareBusco.out, genomes)
		collateBusco(buscoAnnot.out.collect())
}

