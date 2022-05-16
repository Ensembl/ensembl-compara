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

include { ensemblLogo } from './../utilities.nf'

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
    label 'rc_4Gb'
    input:
        path protfa
    output:
        path "longest_busco_proteins.fas", emit: busco_prots
        path "busco_genes.tsv", emit: busco_genes
    script:
    """
    python ${params.longest_busco_filter_exe} -i $protfa -o longest_busco_proteins.fas
    """
}

process buscoAnnot {
    label 'rc_64Gb'
    input:
        path busco_prot
        path genome
    output:
        path "cdna/*.fas"
    script:
    """
    mkdir anno_res
    export ENSCODE=$params.enscode
    ln -s `which tblastn` .
    python3 $params.anno_exe \
    --output_dir anno_res \
    --genome_file $genome \
    --num_threads 30 \
    --max_intron_length 100000 \
    --run_busco 1 \
    --busco_protein_file $busco_prot
    mkdir cdna
    gffread -w cdna/$genome -g $genome anno_res/busco_output/annotation.gtf
    """
}

process collateBusco {
    label 'rc_16gb'

    publishDir "${params.results_dir}/busco_genes", pattern: "cdnas_fofn.txt", mode: "copy"
    publishDir "${params.results_dir}/busco_genes/prot", pattern: "gene_prot_*.fas", mode: "copy"
    publishDir "${params.results_dir}/busco_genes/cdna", pattern: "gene_cdna_*.fas", mode: "copy"
    publishDir "${params.results_dir}/busco_genes", pattern: "busco_stats.tsv", mode: "copy"

    input:
        val cdnas
        path genes_tsv

    output:
        path "cdnas_fofn.txt", emit: fofon
        path "gene_prot_*.fas", emit: prot_seq
        stdout emit:debug
    script:
    fh = new File("$workDir/cdnas_fofn.txt")
    for (line : cdnas)  {
        fh.append("$line\n")
    }
    """
    mv ${workDir}/cdnas_fofn.txt .
    mkdir per_gene
    python ${params.collate_busco_results_exe} -s busco_stats.tsv -i cdnas_fofn.txt -l $genes_tsv -o ./
    """

}

process alignProt {
    label 'rc_16Gb'

    input:
        val protFas
    output:
        path "prot_aln_*.fas", emit: prot_aln
   
    script:
    id = (protFas =~ /.*prot_(.*)\.fas$/)[0][1]
    """
    mafft --auto $protFas > prot_aln_${id}.fas
    # muscle -in  $protFas -out prot_aln_${id}.fas
    """

}

workflow {
    println(ensemblLogo())
    prepareBusco(params.busco_proteins)
    genomes = Channel.fromPath("${params.dir}/*.fas")

    buscoAnnot(prepareBusco.out.busco_prots, genomes)
    collateBusco(buscoAnnot.out.collect(), prepareBusco.out.busco_genes)
    collateBusco.out.debug.view()
    alignProt(collateBusco.out.prot_seq.flatten())
}

