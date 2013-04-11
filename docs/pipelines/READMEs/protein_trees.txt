This document describes how to run ensembl-compara ProteinTrees pipeline.

1. Necessary software components:

	* MySQL 5.1          (or higher)
	* Perl 5.8           (or higher)
	* Perl DBI API 1.6   (or higher)

EnsEMBL and BioPerl software:
	* bioperl-live        - (bioperl-1-2-3 or higher)
	* bioperl-run         - (1.2 or higher) for the CodeML runnable/parser
	* ensembl             - core API on which the rest of ensembl APIs are based
	* ensembl-compara     - Compara API (data objects, db adaptors, pipeline runnables, pipeline configuration)
	* ensembl-analysis    - some of the pipeline runnables live here
	* ensembl-hive        - the system to run pipelines

Refer to the following pages for tips about installation and setting up the environment:
	http://www.ensembl.org/info/docs/api/api_installation.html
	http://www.ensembl.org/info/docs/eHive/installation.html

Any compiled binaries mentioned in ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/EnsemblProteinTrees_conf.pm
( if running outside of Sanger farm you might need to compile your own versions and point at them ) :

        'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_exe'               => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
        'mafft_exe'                 => '/software/ensembl/compara/mafft-6.707/bin/mafft',
        'mafft_binaries'            => '/software/ensembl/compara/mafft-6.707/binaries',
        'sreformat_exe'             => '/usr/local/ensembl/bin/sreformat',
        'treebest_exe'              => '/software/ensembl/compara/treebest.doubletracking',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'buildhmm_exe'              => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
        'codeml_exe'                => '/usr/local/ensembl/bin/codeml',

The pipeline must connect to "master" database to initialize. Please refer to the file "README-master_database" to correctly
set it up. You have to import all the genome_dbs (the species on which you want to run the pipeline) and create a method_link_species_set
with scripts/pipeline/create_mlss.pl using --method_link_type PROTEIN_TREES


2. General structure of the pipeline

You can refer to docs/pipeline_diagrams/ProteinTrees.png for a visual description of the pipeline.

The main structure is given by some backbone analysis. Each one of them will dump the current state of the database (for a backup) and 
fire the next step of the pipeline.
The pipeline will follow one of the two paths (A or B). 'A' is a clustering based on all-vs-all blastp. 'B' is a HMM-based clustering.
The option is selected by the hmm_clustering flag.

   2.1. db_prepare

At this step, the pipeline will make sure that all the tables are running with the MySQL InnoDB database engine. This ensures that foreign keys
will be checked throughout the pipeline. It will also copy over from the master database some core tables:
 ncbi_taxa_node, ncbi_taxa_name, method_link, species_set, method_link_species_set
These tables should be not-empty. If they are, have a look at the file "README-master_database" to populate them.

   2.2. species_list_prepare

At this step, the pipeline will load and check all the species on which you want to run the pipeline. This includes:
 - checking that the connections to each core database are available
 - checking some species-specific data can be reused from a reference Compara database (to save some time at the later stages of the pipeline)
 - building the default species tree (using the NCBI taxonomy)

   2.3. genome_load

At this step, the pipeline will actually load all the data related to the species:
 - the list of members (genes and peptides)
 - the peptide sequences
 - the list of canonical transcripts (in case of alternative splicing: which isoform -which sequence- should be used in the pipeline)

   2.4. (path A) allvsallblast

At this step, the pipeline will run the all-vs-all blastp comparisons. Some hits can be "reused" from the reference compara database, which
can save several weeks of computation

   2.5. (path A) hcluster

At this step, the pipeline will run hcluster_sg on the graph based on the blast hits. The resulting clusters contain similar genes and will
map to individual gene-trees.

   2.6. (path B) hmmClassify

At this step, the pipeline will load all the HMM profiles defined in the library, and classify all the genes from all the species into them.
Each profile will naturally define a cluster.

   2.7. tree_building

At this step, the pipeline will actually compute the trees with the
 - multiple alignment (Mcoffee if the cluster has less than 250 genes, Mafft otherwise)
 - tree reconstruction with TreeBest
 - homology inference

To prevent computation issues, the largest clusters (more than 400 genes) are recursively split into halves (until they fall until the limit size)
with the QuickTree program (after an alignment with Mafft)

  2.8. dnds

At this step, the pipeline will compute dN/dS values on all the homologies (this can be parametrized)


3. Pipeline configuration

The pipeline structure (analysis work-flow) is defined in ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/ProteinTrees_conf.pm but the actual
parameters used by the various groups at the Genome Campus are defined in ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/*ProteinTrees_conf.pm
They mainly include custom:
 - paths to executables
 - database connection parameters
 - more general parameters (pipeline-related)
 - beekeeper parameters

To configure the pipeline, you can:
 - either edit PipeConfig/ProteinTrees_conf.pm (uncomment and update the commented parameters)
 - or copy and update one of the example configuration files

Here follows a description of each category of parameters

   3.1. Path to executables

As stated in the first section of this document, the pipeline relies on some external programs to do the computation.
Make sure that all the necessary software are installed and properly configured.
All the *_exe parameters must point to their correct locations

   3.2 Database connections

The configuration file must contain at least the two following entries:
 - pipeline_db: where the pipeline will create the data
 - master_db: the master database that contains the list of species you want to run the pipeline on and the method_link_species_set object for the current run.

The pipeline relies on some Ensembl core (species) databases to provide the species-specific data. This can be configured with the 'curr_core_sources_locs'
parameter, which is a list of database connections. It should contain the same server list as you have used when running scripts/pipeline/update_genome.pl

If you are going to use Ensembl data, you may want to add the following database description:
'ensembl_srv' => {
	-host   => 'ensembldb.ensembl.org',
	-port   => 5306,
	-user   => 'anonymous',
	-pass   => '',
},
'curr_core_sources_locs' => [ $self->o('ensembl_srv') ],

If you are going to run the pipeline on species that are not in Ensembl, you have to define the "curr_file_sources_locs" parameter with a list
of JSON file of the following format:

[
{
        "production_name" : "nomascus_leucogenys",
        "taxonomy_id"     : "61853",
        "assembly"        : "Nleu2.0",
        "genebuild"       : "2011-05",
        "prot_fasta"      : "proteins.fasta",
        "cds_fasta"       : "transcripts.fasta",
        "gene_coord_gff"  : "annotation.gff",
}
]

If you want to use a Compara database as a reference (for example, to reuse the results of the all-vs-all blastp), you can configure the 'reuse_db' parameter: 
'reuse_db' => {
	-host   => 'ensembldb.ensembl.org',
	-port   => 5306,
	-user   => 'anonymous',
	-pass   => '',
	-dbname => 'ensembl_compara_XXXX',
},
Then, you will have to update the 'reuse_core_sources_locs' parameter. It is equivalent to 'curr_core_sources_locs', but refers to the core databases
linked to 'reuse_db'. Again, on Ensembl data, you can define: 'reuse_core_sources_locs' => [ $self->o('ensembl_srv') ] 
Please make sure that 'prev_release' contains the version number of the reuse database.

   3.3. More general parameters (pipeline-related)

 - mlss_id: the method_link_species_set_id created by scripts/pipeline/create_mlss.pl
   This defines the instance of the pipeline (which species to work on)

 - release: the API version of your CVS checkout

 - rel_suffix: any string (defaults to "") to distinguish between several runs on the same API version

 - work_dir: where to store temporary files
   The pipeline will create there 3 folders:
    - blast_db: the blast databases for the all-vs-all blastp
    - cluster: files used by hcluster_sg
    - dumps: SQL dumps (checkpoints) of the database

 - outgroups: the list of genome_db_ids of the outgroup species.
   This is used by hcluster_sg to produce more relevant clusters. In the Ensembl run, we define S.cerevisae as the outgroup of all the animals (Metazoa)

 - taxlevels: on which clades should the pipeline try to compute dN/dS values.
   Those values are only available for close enough species and it is genereally not a good idea to use very large clades (like Metazoa).
   We only use mammals, some birds and some fish.

   3.4. beekeeper parameters

All the *_capacity parameters are tuned to fit the capacity of our MySQL servers. You migh want to initially reduce them, and gradually increase
them "as long as the database holds" :) The relative proportion of each analysis should probably stay the same

The "resource_classes" of the configuration file defined how beekeeper should run each category of job. These are LSF parameters that you may only
want to change if you don't have a LSF installation

4. Run the pipeline

The pipeline is now ready to be run.
You can swith to the file "README-beekeeper", which explains how to run beekeeper :)



