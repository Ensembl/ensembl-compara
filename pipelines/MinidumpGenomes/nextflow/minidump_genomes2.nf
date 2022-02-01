#!/usr/bin/env nextflow

// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

dumpsDir = file(params.genome_dumps_dir)
dumpsDir.mkdirs()

// Initialise workflow
Channel
    .fromPath(params.species)
    .set { species_json }

process genomeDumpFactory {
    label 'rc_default'

    input:
    path species_json

    output:
    path 'dataflow.json' into dataflow

    shell:
    '''
    python !{params.get_gdb_ids_exe} --url !{params.master_url} --species !{species_json} > dataflow.json
    '''
}

process genomeDumpUnmasked {
    label 'rc_1Gb'

    input:
    val hash from dataflow.splitText()

    output:
    path "${species_name}.*.fa" into fasta_files

    shell:
    genome_db_id = (hash =~ /"genome_db_id": (\d+)/)[0][1]
    species_name = (hash =~ /"species_name": "(\w+)"/)[0][1]
    '''
    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::DumpGenomes::DumpUnmaskedGenomeSequence \
        --reg_conf $COMPARA_REG_PATH \
        --input_id "{'genome_db_id' => !{genome_db_id}, 'genome_dumps_dir' => '!{params.genome_dumps_dir}', \
                     'force_redump' => [], 'compara_db' => '!{params.master_url}'}"
    find !{params.genome_dumps_dir} -type f -name "!{species_name}.*.fa" -exec ln -snf {} . ';'
    '''
}

process buildFaidxIndex {
    label 'rc_default'

    input:
    val genome_dump_file from fasta_files

    output:
    path "${genome_dump_file.name}.fai"

    shell:
    genome_dump_path = "${genome_dump_file.toRealPath()}"
    '''
    (test -e !{genome_dump_path}.fai && test !{genome_dump_path} -ot !{genome_dump_path}.fai) || \
        !{params.samtools_exe} faidx !{genome_dump_path}
    ln -snf !{genome_dump_path}.fai .
    '''
}
