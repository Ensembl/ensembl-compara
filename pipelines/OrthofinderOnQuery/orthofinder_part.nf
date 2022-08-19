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

include {
    updateOrthofinderRun;
} from './../orthofinder_modules.nf'
include { ensemblLogo } from './../utilities.nf'

def helpMessage() {
    log.info ensemblLogo()
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run  pipelines/OrthofinderOnQuery/orthofinder_part.nf --ortho_dir s3_short-term:canis_lupus
      --orthodir [str]      Path to peptide fasta file directory (mandatory)
                                  Example:
                                    s3_short-term:canis_lupus
    """.stripIndent()
}
params.help = ''
if (params.help) {
    helpMessage()
    exit 0
}

if (!params.species) {
    helpMessage()
    exit 0
}

workflow {
    println(ensemblLogo())
    Channel
        .from(params.orthodir)
        .set{ orthodir_ch }

    updateOrthofinderRun(orthodir_ch)
    updateOrthofinderRun.out.view()
}