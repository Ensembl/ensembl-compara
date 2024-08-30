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

// Set up constraint tree path if present:
consNwk = params.cons_nwk
if(consNwk) {
    File consTmp = new File(consNwk)
    consAbsPath = consTmp.getCanonicalPath();
    consNwk = " -g ${consAbsPath}";
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
    echo "iqtree:" >> $out
    ${params.iqtree_exe} --version | grep "version" >> $out
    echo "trimal:" >> $out
    ${params.trimal_exe} --version | grep "build" >> $out
    echo "seqkit:" >> $out
    ${params.seqkit_exe} version >> $out
    echo "astral:" >> $out
    (java -jar $params.astral_jar 2>&1| grep "This is") >> $out
    echo "miniprot:" >> $out
    ${params.miniprot_exe} --version >> $out
    echo "prank" >> $out
    ${params.prank_exe} -version | grep PRANK >> $out
    echo "pagan" >> $out
    ${params.pagan_exe} -v | grep "PAGAN" >> $out
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
    label 'retry_with_16gb_mem_c1'

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
    label 'retry_with_128gb_mem_c32'

    publishDir "${params.results_dir}/anno_cache/$genome", pattern: "annotation.gtf", mode: "copy",  overwrite: true

    input:
        path busco_prot
        path genome
    output:
        tuple path("annotation.gtf"), path(genome), emit: busco_annot
    script:
    if (params.use_anno == "")
    """
        SENS=""
        if [ "${params.sensitive}" != "" ];
        then
            SENS="-M0 -k5"
        fi
        ${params.miniprot_exe} \$SENS -t ${params.cores} -d genome.mpi $genome
        ${params.miniprot_exe} -N 0 -Iu -t ${params.cores} --gff genome.mpi $busco_prot | grep -v '##PAF' \
        | awk -F "\t" 'BEGIN{OFS="\t"} \$3=="mRNA" {match(\$9, /Target=([^; ]+)/, m)} {attribs=gensub(/(ID|Parent)=[^; ]+/, sprintf("\\\\1=%s", m[1]), "g", \$9); \$9=attribs; print}' > annotation.gtf
        rm -f genome.mpi
    """
    else
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
    label 'rc_4Gb'
    input:
        tuple path(busco_annot), path(genome)
    output:
        path "cdna/*"
    script:
    """
    mkdir -p cdna
    ${params.gffread_exe} $busco_annot > anno_clean.gtf
    ${params.gffread_exe} --adj-stop -w cdna/$genome -g $genome anno_clean.gtf
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
    label 'rc_16Gb'

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
process transAlign {
    label 'retry_with_e64gb_mem_c16'

    publishDir "${params.results_dir}/", pattern: "alignments/*_aln_*.fas", mode: "copy",  overwrite: true

    input:
        path cdnas
    output:
        path "alignments/prot_aln_*.fas", emit: prot_aln
        path "alignments/codon_aln_*.fas", emit: codon_aln
   
    script:
    id = (cdnas =~ /.*cdna_(.*)\.fas$/)[0][1]
    """
    mkdir -p alignments
    set +e
    ${params.pagan_exe} -s $cdnas --translate --threads 16 -o pagan_out
    exit_code=\$?
    set -e

    # Check if pagan succeeded
    if [ \$exit_code -eq 0 ]; then
        mv pagan_out.fas alignments/prot_aln_${id}.fas
        mv pagan_out.codon.fas alignments/codon_aln_${id}.fas
    # Check if it failed with a segmentation fault (exit code 139) or ABRT (exit code 134)
    elif [ \$exit_code -eq 139 ] || [ \$exit_code -eq 134 ]; then
        echo "PAGAN failed due to segmentation fault or ABRT, continuing with prank..."
        ${params.prank_exe} -d=$cdnas -o=prank_out -translate +F -once -uselogs
        mv prank_out.best.pep.fas alignments/prot_aln_${id}.fas
        mv prank_out.best.nuc.fas alignments/codon_aln_${id}.fas
    else
        echo "PAGAN failed due to an error other than segmentation fault or ABRT: \$exit_code, exiting."
        exit \$exit_code
    fi 
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
    label 'retry_with_16gb_mem_c1'

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
*@input merged protein alignment fasta
*@output trimmed merged protein alignment fasta
*/
process trimMergedProtAln {
    label 'retry_with_16gb_mem_c1'

    publishDir "${params.results_dir}/", pattern: "trimmed_merged_protein_alns.fas", mode: "copy",  overwrite: true

    input:
        path merged_aln

    output:
        path "trimmed_merged_protein_alns.fas", emit: trimmed_merged_aln
    script:
    """
    ${params.trimal_exe} -in ${merged_aln} -out trimmed_merged_protein_alns.fas -automated1 -keepheader
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
    label 'retry_with_16gb_mem_c1'

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
    label 'retry_with_8gb_mem_c1'

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
*@output path to tree in newick format
*/
process calcProtTrees {
    label 'retry_with_8gb_mem_c32'

    input:
        path aln

    output:
        path "prot_aln_*.treefile", emit: tree
    script:
    """
    # Remove taxa with gaps and stop codons only:
    ${params.seqkit_exe} grep -v -s -r -p "^[*-]*\$" $aln > ${aln}.proc
    # Run iqtree:
    ${params.iqtree_exe} -s ${aln}.proc -m LG+I+G --fast -T ${params.cores}
    """
}

/**
*@input path to newick file with input trees
*@output path to output tree in newick format
*@output path to astral log file
*/
process runAstral {
    label 'retry_with_16gb_mem_c1'

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
*@input path to protein alignment fasta
*@input path to partition file
*@input path to input newick tree
*@output path to output tree in newick format
*@output path to iqtree2 report
*@output path to iqtree2 log file
*/
process refineProtTree {
    label 'retry_with_128gb_mem_c32'

    publishDir "${params.results_dir}/", pattern: "astral_species_tree_prot_bl.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_species_tree_prot_bl_fullid.nwk", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_report_prot_bl.txt", mode: "copy",  overwrite: true
    publishDir "${params.results_dir}/", pattern: "astral_iqtree_log_prot_bl.txt", mode: "copy",  overwrite: true

    input:
        path aln
        path input_tree
        val genomes_csv

    output:
        path "astral_species_tree_prot_bl.nwk", emit: newick
        path "astral_species_tree_prot_bl_fullid.nwk", emit: newick_fullid
        path "astral_iqtree_report_prot_bl.txt", emit: iqrtree_report
        path "astral_iqtree_log_prot_bl.txt", emit: iqtree_log

    script:
    if (params.dir == "")
    """
    ${params.iqtree_exe} -s $aln --mem 100G -m LG+I+G $consNwk -t $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_prot_bl.nwk
    mv *.iqtree astral_iqtree_report_prot_bl.txt
    mv *.log astral_iqtree_log_prot_bl.txt
    cp astral_species_tree_prot_bl.nwk astral_species_tree_prot_bl_fullid.nwk
    python ${params.fix_leaf_names_exe} -t astral_species_tree_prot_bl.nwk -c ${genomes_csv} -o TMP.nwk
    mv TMP.nwk astral_species_tree_prot_bl.nwk
    """
    else
    """
    ${params.iqtree_exe} -s $aln --mem 100G -m LG+I+G $consNwk -t $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_prot_bl.nwk
    mv *.iqtree astral_iqtree_report_prot_bl.txt
    mv *.log astral_iqtree_log_prot_bl.txt
    cp astral_species_tree_prot_bl.nwk astral_species_tree_prot_bl_fullid.nwk
    """
}

/**
*@input path to alignment fasta
*@input path to input newick tree
*@output path to output tree in newick format
*@output path to iqtree2 report
*@output path to iqtree4 log file
*/
process calcNeutralBranches {
    label 'retry_with_128gb_mem_c32'

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
    ${params.iqtree_exe} -s $aln --mem 100G -m GTR+G -g $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_neutral_bl.nwk
    mv *.iqtree astral_iqtree_report_neutral_bl.txt
    mv *.log astral_iqtree_log_neutral_bl.txt
    python ${params.fix_leaf_names_exe} -t astral_species_tree_neutral_bl.nwk -c ${genomes_csv} -o TMP.nwk
    mv TMP.nwk astral_species_tree_neutral_bl.nwk
    """
    else
    """
    ${params.iqtree_exe} -s $aln --mem 100G -m GTR+G -g $input_tree --fast -T ${params.cores}
    mv *.treefile astral_species_tree_neutral_bl.nwk
    mv *.iqtree astral_iqtree_report_neutral_bl.txt
    mv *.log astral_iqtree_log_neutral_bl.txt
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
    transAlign(collateBusco.out.cdnas.flatten())
    
    // Calculate trees from the protein alignments:
    calcProtTrees(transAlign.out.prot_aln)
    trees = calcProtTrees.out.tree.collectFile(name: 'gene_trees.nwk', newLine: true)
    // Run astral to calculate species tree from
    // the gene trees:
    runAstral(trees)
    // Merge protein alignments:
    mergeProtAlns(transAlign.out.prot_aln.collect(), prepareBusco.out.busco_genes, collateBusco.out.taxa)

    // Trim merged protein alignment:
    trimMergedProtAln(mergeProtAlns.out.merged_aln)
    
    // Merge codon alignments:
    mergeCodonAlns(transAlign.out.codon_aln.collect(), prepareBusco.out.busco_genes, collateBusco.out.taxa)
    // Pick out every third site from the merged codon alignment:
    pickThirdCodonSite(mergeCodonAlns.out.merged_aln)
    // Calculate branch lenghts from protein alignment:
    refineProtTree(trimMergedProtAln.out.trimmed_merged_aln, runAstral.out.tree, genCsvChan)
    // Calculate branch lenghts based on the third codon sites:
    calcNeutralBranches(pickThirdCodonSite.out.third_aln, refineProtTree.out.newick_fullid, genCsvChan)
    // Perform outgroup rooting for tree with neutral branch lengths:
    outgroupRootingNeutral(calcNeutralBranches.out.newick)
    // Perform outgroup rooting for tree with protein alignment based branch lengths:
    outgroupRootingProt(refineProtTree.out.newick)
}
