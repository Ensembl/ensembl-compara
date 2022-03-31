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
    // queryFactory; // todo: Include when DataFile API available
    queryTaxonSelectionFactory;
    updateOrthofinderRun;
    mergeRefToQuery
} from './../orthofinder_modules.nf'
include { ensemblLogo } from './../utilities.nf'

def helpMessage() {
    log.info ensemblLogo()
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run  pipelines/OrthofinderOnQuery/main.nf --species canis_lupis_familiaris
    Mandatory arguments:
      --species [str]           Name of ncbi_taxonomy species/genome.
                                Example:
                                    canis_lupis_familiaris (mandatory)
      --genome_fasta [str]      Path to peptide fasta file (optional)
                                  Example:
                                    /ensemblftp/genomes/canis_lupis_familiaris.pep.fasta
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
        .from(params.species)
        .set{ collection_ch }

    // queryFactory(collection_ch) // Not ready yet needs DataFile API
    // queryTaxonSelectionFactory(queryFactory.out) // As above
    queryTaxonSelectionFactory(collection_ch) // Direct parameter usage stop-gap for DataFile API
    // todo: params.genome_fasta to come from metadata.json parseJSONSoloEntry(json_string, key_name)
    // todo: Include data mover S3 wrapper with loop-check on modification before next step
    mergeRefToQuery(collection_ch, params.genome_fasta, queryTaxonSelectionFactory.out)
    updateOrthofinderRun(mergeRefToQuery.out)
    updateOrthofinderRun.out.view()
}
