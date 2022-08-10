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

/**
*@input path to BUSCO gene set protein fasta
*@output path to fasta with longest protein isoforms per gene
*@output path to gene list TSV
*/
process prepareGenome {
    label 'rc_4Gb'
    input:
      path genome

    output:
        path "processed/*", emit: proc_genome
    script:
        id = (genome =~ /(.+)\..+?$/)[0][1]
        """
            mkdir -p processed
            seqkit -j 5 grep -n -v -r -p "PATCH_*,HAP" $genome > processed/$id
        """
}

/**
*@input path to BUSCO gene set protein fasta
*@output path to fasta with longest protein isoforms per gene
*@output path to fasta with filtered out sequences
*@output path to gene list TSV
*/
process prepareBusco {
    label 'rc_4Gb'

    publishDir "${params.results_dir}/busco_genes", pattern: "longest_busco_proteins.fas", mode: "copy", overwrite: true
    publishDir "${params.results_dir}/busco_genes", pattern: "busco_genes.tsv", mode: "copy", overwrite: true
    publishDir "${params.results_dir}/busco_genes", pattern: "repeat_filtered_busco.fas", mode: "copy", overwrite: true

    input:
        path protfa
    output:
        path "longest_busco_proteins.fas", emit: busco_prots
        path "busco_genes.tsv", emit: busco_genes
        path "repeat_filtered_busco.fas", emit: busco_rep
    script:
    """
    python ${params.longest_busco_filter_exe} -r 10 \
    -f repeat_filtered_busco.fas -i $protfa \
    -o longest_busco_proteins.fas -l busco_genes.tsv
    """
}


/**
*@input path to the genome fasta
*@output path to annotation GTF
*@output path to genome fasta
*/
process linkAnnoCache {
    label 'rc_1Gb'

    publishDir "${params.results_dir}/anno_cache/$genome", pattern: "annotation.gtf", mode: "copy",  overwrite: true

    input:
        path genome
    output:
        path "annotation.gtf", emit: busco_annot
        path genome, emit: genome
    script:
    base = new File("$genome")
    base = base.getName()
    """
    ln -s ${params.anno_cache}/$base/annotation.gtf .
    """
}

/**
*@input path to BUSCO longest protein isoforms
*@input path to genome fasta
*@output path to annotation GTF
*@output path to genome fasta
*/
process buscoAnnot {
    label 'retry_with_8gb_mem_c1'

    publishDir "${params.results_dir}/anno_cache/$genome", pattern: "annotation.gtf", mode: "copy",  overwrite: true

    input:
        path busco_prot
        path genome
    output:
        path "annotation.gtf", emit: busco_annot
        path genome, emit: genome
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
    --run_busco \
    --genblast_timeout  64800\
    --busco_protein_file $busco_prot

    mv anno_res/busco_output/annotation.gtf .
    """
}

/**
*@input path to annotation GTF
*@input path to genome fasta
*@output path to cDNA fasta
*/
process runGffread {
    label 'rc_4gb'
    input:
        path busco_annot
        path genome
    output:
        path "cdna/*"
    script:
    """
    mkdir -p cdna
    ${params.gffread_exe} -w cdna/$genome -g $genome $busco_annot
    """
}

/**
*@input list of paths to cDNA fasta files
*@input path to genes list TSV
*@output file of cDNA fasta paths
*@output path to per gene protein sequence fasta
*@output path to per gene cDNA sequence fasta
*@output path to gene stats TSV
*@output path to taxon list TSV
*/
process collateBusco {
    label 'rc_16gb'

    publishDir "${params.results_dir}/busco_genes", pattern: "cdnas_fofn.txt", mode: "copy", overwrite: true
    publishDir "${params.results_dir}/busco_genes/prot", pattern: "gene_prot_*.fas", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/busco_genes/cdna", pattern: "gene_cdna_*.fas", mode: "copy",  overwrite: true
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
    python ${params.collate_busco_results_exe} -s busco_stats.tsv \
    -i cdnas_fofn.txt -l $genes_tsv -o ./ \
    -t taxa.tsv -m ${params.min_taxa}
    """

}

/**
*@input path to protein fasta
*@output path to aligned protein fasta
*/
process alignProt {
    label 'retry_with_4gb_mem_c1'

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

/**
*@input path to protein alignment fasta
*@output path to trimmed protein alignment
*/
process trimAlignments {
    label 'rc_2Gb'

    publishDir "${params.results_dir}/", pattern: "trimmed_alignments/trim_aln_*.fas", mode: "copy",  overwrite: true

    input:
        path full_aln
    output:
        path "trimmed_alignments/trim_aln_*.fas", emit: trim_aln

    script:
    id = (full_aln =~ /.*prot_(.*)\.fas$/)[0][1]
    """
    mkdir -p trimmed_alignments
    trimal -gappyout -in $full_aln -out trimmed_alignments/trim_${id}.fas
    """

}


/**
*@input list of filtered alignments
*@input path to list of genes TSV
*@input path to taxon list TSV
*@output file of alignment file paths
*@output path to merged alignments fasta
*@output path to RAXML style partition file
*/
process mergeAlns {
    label 'rc_4gb'

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

/**
*@input path to merged alignment fasta
*@input path to partition file
*@output path to tree in newick format
*@output path to iqtree2 report
*@output path to iqtree2 log file
*/
process runIqtree {
    label 'retry_with_8gb_mem_c1'
    publishDir "${params.results_dir}/", pattern: "species_tree.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_bionj.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_report.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_log.txt", mode: "copy",  overwrite: true

    input:
        path merged_aln
        path partitions
    output:
        path "species_tree.nwk", emit: newick
        path "iqtree_report.txt", emit: iqrtree_report
        path "iqtree_log.txt", emit: iqtree_log
        path "iqtree_bionj.nwk", emit: iqtree_nj
        stdout emit: debug

    script:
    """
    ${params.iqtree_exe} -s $merged_aln -p $partitions --fast -T ${params.cores}
    mv partitions.tsv.treefile species_tree.nwk
    mv partitions.tsv.iqtree iqtree_report.txt
    mv partitions.tsv.log iqtree_log.txt
    mv partitions.tsv.bionj iqtree_bionj.nwk
    """
}

// Function to check if a genome is present in
// the annotation cache.
def annoInCache(genome, anno_cache) {
    genome = new File("$genome")
    genome = genome.getName()
    File file = new File("${anno_cache}/${genome}/annotation.gtf")
    return file.exists()
}

workflow {
    println(ensemblLogo())

    // Prepare busco protein set:
    prepareBusco(params.busco_proteins)

    // Prepare input genomes:
    genomes = Channel.fromPath("${params.dir}/*.*")
    prepareGenome(genomes)

    // Branch the genomes channel based on presence in the
    // annotation cache:
    prepareGenome.out.proc_genome.branch {
        annot: !annoInCache(it, params.anno_cache)
        link: annoInCache(it, params.anno_cache)
    }.set { genome_fork }

    // Link annotations present in the cache:
    linkAnnoCache(genome_fork.link)
    // Annotate genomes not present in the cache:
    buscoAnnot(prepareBusco.out.busco_prots, genome_fork.annot)

    // Merge the output of link and annotate steps:
    genomes = buscoAnnot.out.genome.mix(linkAnnoCache.out.genome)
    annots = buscoAnnot.out.busco_annot.mix(linkAnnoCache.out.busco_annot)

    // Get cDNA from the genomes and annotations:
    runGffread(annots, genomes)
 
    // Organise sequences per-gene:
    collateBusco(runGffread.out.collect(), prepareBusco.out.busco_genes)

    // Align protein sequences:
    alignProt(collateBusco.out.prot_seq.flatten())

    // Trim protein alignments:
    trimAlignments(alignProt.out.prot_aln)

    // Merge alignments:
    mergeAlns(trimAlignments.out.trim_aln.collect(), prepareBusco.out.busco_genes, collateBusco.out.taxa)

    // Calculate species tree using iqtree2:
    runIqtree(mergeAlns.out.merged_aln, mergeAlns.out.partitions)
}
