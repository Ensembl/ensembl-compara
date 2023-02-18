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

include { orthoFinderFactory; runOrthoFinder } from './../orthofinder_modules.nf'
include { listSubDirs; ensemblLogo } from './../utilities.nf'

def helpMessage() {
    log.info ensemblLogo()
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run  pipelines/OrthofinderOnReferences/main.nf --dir collection_fasta
    Mandatory arguments:
      --dir [directory]     Directory containing subdirectories of reference collection fasta files.
                            (mandatory)
                              Example:
                                |--collection_fasta
                                      |-- actinopterygii
                                      |   |-- amblyraja_radiata.sAmbRad1.pri.2020-06.fasta
                                      |   |-- arabidopsis_thaliana.TAIR10.2010-09.fasta
                                      |   |-- xenopus_tropicalis.Xenopus_tropicalis_v9.1.2019-12.fasta
                                      |-- default
                                          |-- amphimedon_queenslandica.Aqu1.2015-05-Degnan.fasta
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

// Manage available directories for orthoFinderFactory
base_dir = file(params.dir)
dir_list = listSubDirs(base_dir, "references")

workflow {
    println(ensemblLogo())
    // The starting flow of data to use in the orthofinder factory (first process)
    Channel
        .from(dir_list)
        .set{ collection_ch }

    orthoFinderFactory(collection_ch)
    runOrthoFinder(orthoFinderFactory.out)
}
