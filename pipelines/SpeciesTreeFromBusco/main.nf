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
    Usage examples:

    * Basic usage:
        \$ nextflow run main.nf --dir /path/to/fastas/ --results_dir ./Res

    * Using cached annotations:
        \$ nextflow run main.nf --dir /path/to/fastas/ --results_dir ./Res --anno_cache /absolute/path/to/Res/anno_cache

    * Using collection in compara master database and shared dumps as input:
        \$ nextflow run main.nf --url='mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master' --collection pig_breeds \
        --dump_path /hps/nobackup/flicek/ensembl/compara/shared/genome_dumps/vertebrates --results_dir ./Res

    * Using species set in compara master database and shared dumps as input:
        \$ nextflow run main.nf --url='mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master' --species_set 81206 \
        --dump_path /hps/nobackup/flicek/ensembl/compara/shared/genome_dumps/vertebrates --results_dir ./Res

    See 'nextflow.config' for additional options.

    """.stripIndent()
}

params.help = ''
if (params.help) {
    helpMessage()
    exit 0
}

if (!params.dir && !params.url) {
    helpMessage()
    exit 0
}

File fileResDir = new File(params.results_dir);
absResPath = fileResDir.getCanonicalPath();

File annoCacheDir = new File(params.anno_cache);
absAnnoCache = annoCacheDir.getCanonicalPath();

File dumpPathDir = new File(params.dump_path);
absDumpPath = dumpPathDir.getCanonicalPath();


/**
*@output path to text file with software versions
*/
process dumpVersions {
    label 'rc_1Gb'

    publishDir "${params.results_dir}/", pattern: "software_versions.txt", mode: "copy", overwrite: true

    output:
        path "software_versions.txt", emit: versions
    script:
    out = "software_versions.txt"
    """
    echo "Software versions" >> $out
    echo "-----------------" >> $out
    echo "python:" >> $out
    python --version >> $out
    echo "perl:" >> $out
    perl -v | grep "This is" >> $out
    echo "gffread:" >> $out
    ${params.gffread_exe} --version >> $out
    echo "mafft:" >> $out
    (${params.mafft_exe} --version 2>&1) >> $out
    echo "iqtree:" >> $out
    ${params.iqtree_exe} --version | grep "version" >> $out
    echo "trimal:" >> $out
    ${params.trimal_exe} --version | grep "build" >> $out
    echo "seqkit:" >> $out
    ${params.seqkit_exe} version >> $out
    echo "gotree:" >> $out
    ${params.gotree_exe} version >> $out
    echo "pal2nal:" >> $out
    (${params.pal2nal_exe} 2>&1| grep "(v") >> $out
    echo "astral:" >> $out
    (java -jar $params.astral_jar 2>&1| grep "This is") >> $out
    echo "macse:" >> $out
    (java -jar $params.macse_jar -help 2>&1| grep "This is") >> $out
    """

}

/**
*@input path to genome
*@output path to processed genome
*/
process prepareGenome {
    label 'retry_with_8gb_mem_c1'
    input:
        path genome
    output:
        path "processed/*", emit: proc_genome
    when: params.dir != ""
    script:
        id = (genome =~ /(.+)\.fas?(\.gz)?$/)[0][1]
        """
            mkdir -p processed
            ${params.seqkit_exe} -j 5 grep -n -v -r -p "PATCH_*,HAP" $genome > processed/$id
            # Add a dummy softmasked sequence to prevent disabling of
            # blast softmasking during the genblast processing:
            echo -e ">REPMASK_DUMMY_DECOY\na" >> processed/$id
        """
}

/**
*@output path to processed genome
*@output path to input genomes info csv
*/
process prepareGenomeFromDb {
    label 'retry_with_8gb_mem_c1'

    publishDir "${params.results_dir}", pattern: "input_genomes.csv", mode: "copy", overwrite: true

    output:
        path "processed/*", emit: proc_genome
        path "input_genomes.csv", emit: input_genomes
    when: params.dir == ""
    script:
        """
            mkdir -p processed
            python ${params.fetch_genomes_exe} -u ${params.url} -c "${params.collection}" -s "${params.species_set}" -d ${absDumpPath} -o input_genomes.csv
            while read -r line; do
                source=`echo "\$line" | cut -f 8`
                target=`echo "\$line" | cut -f 10`
                echo Processing: \$source -> \$target
                ${params.seqkit_exe} -j 5 grep -n -v -r -p "PATCH_*,HAP" \$source > processed/\$target
                # Add a dummy softmasked sequence to prevent disabling of
                # blast softmasking during the genblast processing:
                echo -e ">REPMASK_DUMMY_DECOY\na" >> processed/\$target
            done < input_genomes.csv
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
*@output tuple of path to annotation GTF and genome fasta
*/
process linkAnnoCache {
    label 'rc_1Gb'

    publishDir "${params.results_dir}/anno_cache/$genome", pattern: "annotation.gtf", mode: "copy",  overwrite: true

    input:
        path genome
    output:
        tuple path("annotation.gtf"), path(genome), emit: busco_annot
    script:
    base = new File("$genome")
    base = base.getName()
    """
    ln -s ${absAnnoCache}/$base/annotation.gtf .
    """
}

/**
*@input path to BUSCO longest protein isoforms
*@input path to genome fasta
*@output tuple of path to annotation GTF and genome fasta
*/
process buscoAnnot {
    label 'retry_with_32gb_mem_c32'

    publishDir "${params.results_dir}/anno_cache/$genome", pattern: "annotation.gtf", mode: "copy",  overwrite: true

    input:
        path busco_prot
        path genome
    output:
        tuple path("annotation.gtf"), path(genome), emit: busco_annot
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
*@input tuple of path to annotation GTF and genome fasta
*@output path to cDNA fasta
*/
process runGffread {
    label 'rc_4gb'
    input:
        tuple path(busco_annot), path(genome)
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
*@output path to cDNA fasta
*/
process alignProt {
    label 'retry_with_4gb_mem_c1'

    input:
        val protFas
        path cdnas
    output:
        path "alignments/prot_aln_*.fas", emit: prot_aln
        path cdnas, emit: cdnas
   
    script:
    id = (protFas =~ /.*prot_(.*)\.fas$/)[0][1]
    """
    mkdir -p alignments
    ${params.mafft_exe} --anysymbol --auto $protFas > alignments/prot_aln_${id}.fas
    """
}

/**
*@input path to protein alignment fasta
*@output path to cDNA sequences fasta
*@output path to codon alignment fasta
*/
process protAlnToCodon {
    label 'rc_1Gb'

    input:
        path prot_aln
        val cdna
    output:
        path "alignments/codon_aln_*.fas", emit: codon_aln

    script:
    id = (prot_aln =~ /.*prot_aln_(.*)\.fas$/)[0][1]
    """
    mkdir -p alignments

    # Filter out from the cDNA sequences which did not pass protein
    # level filtering:
    ${params.seqkit_exe} -j 5 fx2tab -n $prot_aln > prot.ids
    ${params.seqkit_exe} grep -j 5 -n -f prot.ids $cdna > filtered_cdna.fas
    # Convert AA to codon alignment:
    ${params.pal2nal_exe} $prot_aln filtered_cdna.fas -output fasta > alignments/codon_aln_${id}.fas
    if [ -s alignments/codon_aln_${id}.fas ];
    then
        true;
    else
        echo "Codon alignment is empty!"
        exit 1
    fi
    """
}

/**
*@input path to codon alignment fasta
*@output path to codon alignment fasta with stop codons removed
*/
process removeStopCodons {
    label 'rc_1Gb'

    publishDir "${params.results_dir}/", pattern: "alignments/codon_aln_*.fas", mode: "copy",  overwrite: true

    input:
        path codon_aln
    output:
        path "alignments/codon_aln_*.fas", emit: codon_aln

    script:
    id = (codon_aln =~ /.*codon_aln_(.*)\.fas$/)[0][1]
    """
    mkdir -p alignments
    java -jar ${params.macse_jar} -prog exportAlignment \
    -align $codon_aln \
    -codonForFinalStop --- \
    -codonForInternalStop NNN \
    -out_NT alignments/codon_aln_${id}.fas
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
process mergeProtAlns {
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
*@input list of filtered alignments
*@input path to list of genes TSV
*@input path to taxon list TSV
*@output file of alignment file paths
*@output path to merged alignments fasta
*/
process mergeCodonAlns {
    label 'rc_4gb'

    publishDir "${params.results_dir}/", pattern: "merged_codon_alns.fas", mode: "copy",  overwrite: true

    input:
        val alns
        path genes_tsv
        path taxa

    output:
        path "codon_alns_fofn.txt", emit: alns_fofn
        path "merged_codon_alns.fas", emit: merged_aln

    script:
    fh = new File("$workDir/codon_alns_fofn.txt")
    for (line : alns)  {
        fh.append("$line\n")
    }
    """
    mv ${workDir}/codon_alns_fofn.txt .
    python ${params.alignments_to_partitions_exe} -i codon_alns_fofn.txt -o merged_codon_alns.fas -p codon_partitions.tsv -t $taxa
    """
}

/**
*@input codon alignment fasta
*@output fasta alignment with every third site.
*/
process pickThirdCodonSite {
    label 'rc_4gb'

    publishDir "${params.results_dir}/", pattern: "merged_third_sites_alns.fas", mode: "copy",  overwrite: true

    input:
        path codon_aln

    output:
        path "merged_third_sites_alns.fas", emit: third_aln
    script:
    """
    python ${params.pick_third_site_exe} -i $codon_aln -o merged_third_sites_alns.fas
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
    label 'retry_with_16gb_mem_c1'
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

/**
*@input path to merged alignment fasta
*@output path to tree in newick format
*/
process calcGeneTrees {
    label 'retry_with_8gb_mem_c1'

    input:
        path aln

    output:
        path "codon_aln_*.treefile", emit: tree
    script:
    """
    ${params.iqtree_exe} -st CODON -s $aln -m KOSI07_GY+F+G --fast -T ${params.cores}
    """
}

/**
*@input path to merged alignment fasta
*@output path to tree in newick format
*/
process calcProtTrees {
    label 'retry_with_8gb_mem_c1'

    input:
        path aln

    output:
        path "prot_aln_*.treefile", emit: tree
    script:
    """
    # Remove taxa with gaps and stop codons only:
    ${params.seqkit_exe} grep -v -s -r -p "^[*-]*\$" $aln > ${aln}.proc
    # Run iqtree:
    ${params.iqtree_exe} -s ${aln}.proc -m LG+F+G --fast -T ${params.cores}
    """
}

/**
*@input path to newick file with input trees
*@output path to output tree in newick format
*@output path to astral log file
*/
process runAstral {
    label 'retry_with_8gb_mem_c1'

    publishDir "${params.results_dir}/", pattern: "astral_species_tree.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral.log", mode: "copy",  overwrite: true

    input:
        path trees

    output:
        path "astral_species_tree.nwk", emit: tree
        path "astral.log", emit: log
    script:
    """
    ln -s `dirname ${params.astral_jar}`/lib .
    (java -jar ${params.astral_jar} -i $trees -o astral_species_tree.nwk 2>&1) > astral.log
    """
}

/**
*@input path to merged codon alignment fasta
*@input path to input newick tree
*@output path to output tree in newick format
*@output path to iqtree2 report
*@output path to iqtree2 log file
*/
process calcCodonBranchesIqtree {
    label 'retry_with_16gb_mem_c1'

    publishDir "${params.results_dir}/", pattern: "species_tree_codon_bl.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_report_codon_bl.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "iqtree_log_codon_bl.txt", mode: "copy",  overwrite: true


    input:
        path codon_aln
        path input_tree

    output:
        path "species_tree_codon_bl.nwk", emit: newick
        path "iqtree_report_codon_bl.txt", emit: iqrtree_report
        path "iqtree_log_codon_bl.txt", emit: iqtree_log

    script:
    """
    ${params.iqtree_exe} -st CODON -s $codon_aln -m KOSI07_GY+F -g $input_tree --fast -T ${params.cores}
    mv merged_codon_alns.fas.treefile species_tree_codon_bl.nwk
    mv merged_codon_alns.fas.iqtree iqtree_report_codon_bl.txt
    mv merged_codon_alns.fas.log iqtree_log_codon_bl.txt
    """
}

/**
*@input path to alignment fasta
*@input path to input newick tree
*@output path to output tree in newick format
*@output path to iqtree2 report
*@output path to iqtree2 log file
*/
process calcNeutralBranchesAstral {
    label 'retry_with_16gb_mem_c1'

    publishDir "${params.results_dir}/", pattern: "astral_species_tree_neutral_bl.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_report_neutral_bl.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_log_neutral_bl.txt", mode: "copy",  overwrite: true

    input:
        path aln
        path input_tree
        val genomes_csv

    output:
        path "astral_species_tree_neutral_bl.nwk", emit: newick
        path "astral_iqtree_report_neutral_bl.txt", emit: iqrtree_report
        path "astral_iqtree_log_neutral_bl.txt", emit: iqtree_log

    script:
    if (params.dir == "")
    """
    ${params.iqtree_exe} -s $aln -m GTR+G -g $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_neutral_bl.nwk
    mv *.iqtree astral_iqtree_report_neutral_bl.txt
    mv *.log astral_iqtree_log_neutral_bl.txt
    python ${params.fix_leaf_names_exe} -t astral_species_tree_neutral_bl.nwk -c ${genomes_csv} -o TMP.nwk
    mv TMP.nwk astral_species_tree_neutral_bl.nwk
    """
    else
    """
    ${params.iqtree_exe} -s $aln -m GTR+G -g $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_neutral_bl.nwk
    mv *.iqtree astral_iqtree_report_neutral_bl.txt
    mv *.log astral_iqtree_log_neutral_bl.txt
    """

}

/**
*@input path to codon alignment fasta
*@input path to input newick tree
*@output path to output tree in newick format
*@output path to iqtree2 report
*@output path to iqtree2 log file
*/
process calcCodonBranchesAstral {
    label 'retry_with_16gb_mem_c1'

    publishDir "${params.results_dir}/", pattern: "astral_species_tree_codon_bl.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_report_codon_bl.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_log_codon_bl.txt", mode: "copy",  overwrite: true

    input:
        path codon_aln
        path input_tree

    output:
        path "astral_species_tree_codon_bl.nwk", emit: newick
        path "astral_iqtree_report_codon_bl.txt", emit: iqrtree_report
        path "astral_iqtree_log_codon_bl.txt", emit: iqtree_log

    script:
    """
    ${params.iqtree_exe} -st CODON -s $codon_aln -m KOSI07_GY+F -g $input_tree --fast -T ${params.cores}
    mv merged_codon_alns.fas.treefile astral_species_tree_codon_bl.nwk
    mv merged_codon_alns.fas.iqtree astral_iqtree_report_codon_bl.txt
    mv merged_codon_alns.fas.log astral_iqtree_log_codon_bl.txt
    """
}

/**
*@input path to protein alignment fasta
*@input path to partition file
*@input path to input newick tree
*@output path to output tree in newick format
*@output path to iqtree2 report
*@output path to iqtree2 log file
*/
process calcProtBranchesAstral {
    label 'retry_with_16gb_mem_c1'

    publishDir "${params.results_dir}/", pattern: "astral_species_tree_prot_bl.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_report_prot_bl.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_log_prot_bl.txt", mode: "copy",  overwrite: true

    input:
        path aln
        path partitions
        path input_tree
        val genomes_csv

    output:
        path "astral_species_tree_prot_bl.nwk", emit: newick
        path "astral_iqtree_report_prot_bl.txt", emit: iqrtree_report
        path "astral_iqtree_log_prot_bl.txt", emit: iqtree_log

    script:
    if (params.dir == "")
    """
    ${params.iqtree_exe} -s $aln -p $partitions -g $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_prot_bl.nwk
    mv *.iqtree astral_iqtree_report_prot_bl.txt
    mv *.log astral_iqtree_log_prot_bl.txt
    python ${params.fix_leaf_names_exe} -t astral_species_tree_prot_bl.nwk -c ${genomes_csv} -o TMP.nwk
    mv TMP.nwk astral_species_tree_prot_bl.nwk
    """
    else
    """
    ${params.iqtree_exe} -s $aln -p $partitions -g $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_prot_bl.nwk
    mv *.iqtree astral_iqtree_report_prot_bl.txt
    mv *.log astral_iqtree_log_prot_bl.txt
    """
}

/**
*@input path to input tree with codon branch lengths
*@output path to output tree with nucleotide branch lengths
*/
process scaleToNucleotide {
    label 'rc_2Gb'

    publishDir "${params.results_dir}/", pattern: "astral_species_tree_nuc_bl.nwk", mode: "copy",  overwrite: true

    input:
        path in_tree

    output:
        path "astral_species_tree_nuc_bl.nwk", emit: tree

    script:
    """
    ${params.gotree_exe} brlen scale -f 0.33333333333 < $in_tree > astral_species_tree_nuc_bl.nwk
    """
}

/**
*@input path to unrooted input tree
*@output path to rooted output tree
*/
process outgroupRootingNeutral {
    label 'rc_2Gb'

    publishDir "${params.results_dir}/", pattern: "rooted_*.nwk", mode: "copy",  overwrite: true

    input:
        path utree

    output:
        path "rooted_*.nwk", emit: tree
    when: params.outgroup != ""
    script:
    """
    ${params.rooting_exe} -t $utree -o ${params.outgroup} > rooted_`basename $utree`
    """
}

/**
*@input path to unrooted input tree
*@output path to rooted output tree
*/
process outgroupRootingProt {
    label 'rc_2Gb'

    publishDir "${params.results_dir}/", pattern: "rooted_*.nwk", mode: "copy",  overwrite: true

    input:
        path utree

    output:
        path "rooted_*.nwk", emit: tree
    when: params.outgroup != ""
    script:
    """
    ${params.rooting_exe} -t $utree -o ${params.outgroup} > rooted_`basename $utree`
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

    // Dump software versions:
    dumpVersions()

    // Prepare busco protein set:
    prepareBusco(params.busco_proteins)

    // Prepare input genomes:
    if (params.dir != "") {
        // Get a channel of input genomes if directory is specified:
        genomes = Channel.fromPath("${params.dir}/*.fa{,s}{,.gz}", type: 'file')
    } else {
        // Otherwise initialise an empty channel to avoid nextflow crash:
        genomes = Channel.of()
    }
    prepareGenome(genomes)
    prepareGenomeFromDb()

    if (params.dir == "") {
        // The input is from DB, the genomes CSV comes from the process:
        genCsvChan = prepareGenomeFromDb.out.input_genomes
    } else {
        // The input is from fasta file, specify a dummy path for the
        // CSV file so the branch length calculations are executed:
        genCsvChan = Channel.of("/dummy/path")
    }

    proc_genomes = prepareGenome.out.proc_genome.flatten().mix(prepareGenomeFromDb.out.proc_genome.flatten())

    // Branch the genomes channel based on presence in the
    // annotation cache:
    proc_genomes.branch {
        annot: !annoInCache(it, params.anno_cache)
        link: annoInCache(it, params.anno_cache)
    }.set { genome_fork }

    // Link annotations present in the cache:
    linkAnnoCache(genome_fork.link)
    // Annotate genomes not present in the cache:
    buscoAnnot(prepareBusco.out.busco_prots, genome_fork.annot)

    // Merge the output of link and annotate steps:
    annots = buscoAnnot.out.busco_annot.mix(linkAnnoCache.out.busco_annot)

    // Get cDNA from the genomes and annotations:
    runGffread(annots)

    // Organise sequences per-gene:
    collateBusco(runGffread.out.collect(), prepareBusco.out.busco_genes)

    // Align protein sequences:
    alignProt(collateBusco.out.prot_seq.flatten(), collateBusco.out.cdnas.flatten())

    // Trim protein alignments (removed):
    trimAlignments(alignProt.out.prot_aln)

    // Convert protein alignments to codon alignment:
    protAlnToCodon(alignProt.out.prot_aln, alignProt.out.cdnas)

    // Remove stop codons from codon alignment:
    removeStopCodons(protAlnToCodon.out.codon_aln)

    // Calculate trees from the codon alignments (removed):
    // calcGeneTrees(removeStopCodons.out.codon_aln)

    // Calculate trees from the protein alignments:
    calcProtTrees(alignProt.out.prot_aln)

    trees = calcProtTrees.out.tree.collectFile(name: 'gene_trees.nwk', newLine: true)

    // Run astral to calculate species tree from
    // the gene trees:
    runAstral(trees)

    // Merge protein alignments:
    mergeProtAlns(trimAlignments.out.trim_aln.collect(), prepareBusco.out.busco_genes, collateBusco.out.taxa)

    // Merge codon alignments:
    mergeCodonAlns(removeStopCodons.out.codon_aln.collect(), prepareBusco.out.busco_genes, collateBusco.out.taxa)

    // Pick out every third site from the merged codon alignment:
    pickThirdCodonSite(mergeCodonAlns.out.merged_aln)

    // Calculate branch lenghts based on the third codon sites:
    calcNeutralBranchesAstral(pickThirdCodonSite.out.third_aln, runAstral.out.tree, genCsvChan)

    // Calculate species tree from protein alignments using iqtree2 (removed):
    // runIqtree(mergeProtAlns.out.merged_aln, mergeProtAlns.out.partitions)

    // Calculate neutral branch lenghts from codon alignment (removed):
    // calcCodonBranchesIqtree(mergeCodonAlns.out.merged_aln, runIqtree.out.newick)

    // Calculate branch lenghts from protein alignment:
    calcProtBranchesAstral(mergeProtAlns.out.merged_aln, mergeProtAlns.out.partitions, runAstral.out.tree, genCsvChan)

    // Calculate branch lenghts from codon alignment for the astral tree (removed):
    // calcCodonBranchesAstral(mergeCodonAlns.out.merged_aln, runAstral.out.tree)

    // Scale the branch lengths to nucleotide sites (removed):
    // scaleToNucleotide(calcCodonBranchesAstral.out.newick)

    // Perform outgroup rooting for tree with neutral branch lengths:
    outgroupRootingNeutral(calcNeutralBranchesAstral.out.newick)
    // Perform outgroup rooting for tree with protein alignment based branch lengths:
    outgroupRootingProt(calcProtBranchesAstral.out.newick)
}
