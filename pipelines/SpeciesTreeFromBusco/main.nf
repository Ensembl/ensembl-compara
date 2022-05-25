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
    label 'lsf_16Gb'

    input:
        path busco_prot
        path genome
    output:
        path "cdna/*.fas"
    script:
    """
    mkdir -p anno_res
    export ENSCODE=$params.enscode
    ln -s `which tblastn` .
    python3 $params.anno_exe \
    --output_dir anno_res \
    --genome_file $genome \
    --num_threads ${params.cores} \
    --max_intron_length 100000 \
    --run_busco 1 \
    --busco_protein_file $busco_prot
    mkdir -p cdna
    ${params.gffread_exe} -w cdna/$genome -g $genome anno_res/busco_output/annotation.gtf
    """
}

process collateBusco {
    label 'rc_16gb'

    publishDir "${params.results_dir}/busco_genes", pattern: "cdnas_fofn.txt", mode: "copy", overwrite: true
    publishDir "${params.results_dir}/busco_genes/prot", pattern: "gene_prot_*.fas", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/busco_genes", pattern: "busco_stats.tsv", mode: "copy",  overwrite: true

    input:
        val cdnas
        path genes_tsv

    output:
        path "cdnas_fofn.txt", emit: fofn
        path "gene_prot_*.fas", emit: prot_seq
        path "gene_cdna_*.fas", emit: cdnas
        path "busco_stats.tsv", emit: stats
        path "taxa.tsv", emit: taxa
    script:
    fh = new File("$workDir/cdnas_fofn.txt")
    for (line : cdnas)  {
        fh.append("$line\n")
    }
    """
    mv ${workDir}/cdnas_fofn.txt .
    mkdir -p per_gene
    python ${params.collate_busco_results_exe} -s busco_stats.tsv -i cdnas_fofn.txt -l $genes_tsv -o ./ -t taxa.tsv
    """

}

process alignProt {
    label 'rc_16Gb'

    publishDir "${params.results_dir}/", pattern: "alignments/prot_aln_*.fas", mode: "copy",  overwrite: true

    input:
        val protFas
    output:
        path "alignments/prot_aln_*.fas", emit: prot_aln
   
    script:
    id = (protFas =~ /.*prot_(.*)\.fas$/)[0][1]
    """
    mkdir -p alignments
    ${params.mafft_exe} --auto $protFas > alignments/prot_aln_${id}.fas
    """

}

process mergeAlns {
    label 'rc_24gb'

    publishDir "${params.results_dir}/", pattern: "merged_protein_alns.fas", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "partitions.tsv", mode: "copy",  overwrite: true

    input:
        val alns
        path genes_tsv
        path taxa

    output:
        path "alns_fofn.txt", emit: alns_fofn
        path "merged_protein_alns.fas", emit: merged_aln
        path "partitions.tsv", emit: partitions
        stdout emit: debug
    script:
    fh = new File("$workDir/alns_fofn.txt")
    for (line : alns)  {
        fh.append("$line\n")
    }
    """
    mv ${workDir}/alns_fofn.txt .
    python ${params.alignments_to_partitions_exe} -i alns_fofn.txt -o merged_protein_alns.fas -p partitions.tsv -t $taxa
    """

}
process runIqtree {
    label 'rc_32gb'
    cpus 30

    publishDir "${params.results_dir}/", pattern: "species_tree.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_report.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_log.txt", mode: "copy",  overwrite: true

    input:
        path merged_aln
        path partitions
    output:
        path "species_tree.nwk", emit: newick
        path "iqtree_report.txt", emit: iqrtree_report
        path "iqtree_log.txt", emit: iqtree_log
        stdout emit: debug

    script:
    """
    ${params.iqtree_exe} -s $merged_aln -p $partitions -nt ${params.cores}
    mv partitions.tsv.treefile species_tree.nwk
    mv partitions.tsv.iqtree iqtree_report.txt
    mv partitions.tsv.log iqtree_log.txt
    """
}

workflow {
    println(ensemblLogo())
    prepareBusco(params.busco_proteins)
    genomes = Channel.fromPath("${params.dir}/*.fas")

    buscoAnnot(prepareBusco.out.busco_prots, genomes)
    collateBusco(buscoAnnot.out.collect(), prepareBusco.out.busco_genes)
    alignProt(collateBusco.out.prot_seq.flatten())
    mergeAlns(alignProt.out.prot_aln.collect(), prepareBusco.out.busco_genes, collateBusco.out.taxa)
    mergeAlns.out.debug.view()
    runIqtree(mergeAlns.out.merged_aln, mergeAlns.out.partitions)
}

