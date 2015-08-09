This document explains how to set up an initial master database and then update it for a new species or analysis

1- Description of the master database
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The master database is used to maintain certain internal ids between different databases and ensembl releases. For example, the genome_db table contains information about a particular species assembly. By maintaining this table in the master and then copying to the production and release databases, the genome_db_id will be consistent for the same species and assembly, even between releases. 

Populated tables:

dnafrag                  toplevel sequence names, generally chromosomes or supercontigs
genome_db                species
mapping_session          list of the stable ID mappings that have been performed for families and gene trees
meta                     should only contain these keys: "schema_version" and "schema_type"
method_link              comparison methods
method_link_species_set  combine comparison method with set of species
ncbi_taxa_name           all the various tags, names, etc, attached to the NCBI taxonomy
ncbi_taxa_node           the complete NCBI taxonomy, stored as a tree structure
species_set_header       description of set of species
species_set              content of the species-sets
species_set_tag          species-set specific tags


1- code API needed
   ~~~~~~~~~~~~~~~

  bioperl-live (bioperl-1-2-3 as per the official Ensembl requirement. Some pipelines may require a more recent version, though)
  ensembl
  ensembl-compara
  ensembl-hive
  ensembl-analysis

1.1 Code checkout

      git clone https://github.com/Ensembl/ensembl.git
      git clone https://github.com/Ensembl/ensembl-compara.git
      git clone https://github.com/Ensembl/ensembl-hive.git
      git clone https://github.com/Ensembl/ensembl-analysis.git

By default, the latest stable version of the API is checked out.
Do "git checkout release/XXXX" (where XXXX is the API version you are interested in -e.g. 73- ) in each of the above directories should you need a specific version.

in tcsh
    setenv ENSEMBL_CVS_ROOT_DIR  /some/path/to/base/dir
    setenv PERL5LIB  ${ENSEMBL_CVS_ROOT_DIR}/ensembl/modules:${ENSEMBL_CVS_ROOT_DIR}/bioperl-live:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-analysis/modules:${PERL5LIB}
    setenv PATH $PATH:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/script/pipeline:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/scripts

in bash
    ENSEMBL_CVS_ROOT_DIR=/some/path/to/base/dir
    PERL5LIB=${ENSEMBL_CVS_ROOT_DIR}/ensembl/modules:${ENSEMBL_CVS_ROOT_DIR}/bioperl-live:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-analysis/modules:${PERL5LIB}
    PATH=$PATH:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/scripts/pipeline:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/scripts

eHive automatically sets PERL5LIB up at runtime. Please only do the following if you need to develop your own eHive modules:
    setenv PERL5LIB ${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/modules:${PERL5LIB}
 (or)
    PERL5LIB=${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/modules:${PERL5LIB}

2- Create master database
   ~~~~~~~~~~~~~~~~~~~~~~

Create an empty database with the compara schema

mysql -h HOST -P PORT -u USER -pPASS -e "create database kb3_ensembl_compara_master"
mysql -h HOST -P PORT -u USER -pPASS kb3_ensembl_compara_master < $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/sql/table.sql


3- Populate the master database
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

3.1 Populate the method_link table with the required methods. 

The easiest way to populate this table is to take the entries from the current live site
eg (replacing XXXX with the current version number)

mysqldump -uanonymous -hensembldb.ensembl.org -P5306 --skip-lock-tables ensembl_compara_XXXX method_link | mysql -u USER -pPASS -h HOST -D DB_NAME

OR use a mysql insert statement for the method you need
eg
INSERT INTO method_link (method_link_id, type, class) VALUES (16, "LASTZ_NET", "GenomicAlignBlock.pairwise_alignment");


The currently supported methods are:
+----------------+--------------------------+----------------------------------------+
| method_link_id | type                     | class                                  |
+----------------+--------------------------+----------------------------------------+
|              1 | BLASTZ_NET               | GenomicAlignBlock.pairwise_alignment   |
|              7 | TRANSLATED_BLAT_NET      | GenomicAlignBlock.pairwise_alignment   |
|             10 | PECAN                    | GenomicAlignBlock.multiple_alignment   |
|             11 | GERP_CONSTRAINED_ELEMENT | ConstrainedElement.constrained_element |
|             13 | EPO                      | GenomicAlignTree.ancestral_alignment   |
|             14 | EPO_LOW_COVERAGE         | GenomicAlignTree.tree_alignment        |
|             16 | LASTZ_NET                | GenomicAlignBlock.pairwise_alignment   |
|             19 | LASTZ_PATCH              | GenomicAlignBlock.pairwise_alignment   |
|            101 | SYNTENY                  | SyntenyRegion.synteny                  |
|            201 | ENSEMBL_ORTHOLOGUES      | Homology.homology                      |
|            202 | ENSEMBL_PARALOGUES       | Homology.homology                      |
|            205 | ENSEMBL_PROJECTIONS      | Homology.homology                      |
|            301 | FAMILY                   | Family.family                          |
|            401 | PROTEIN_TREES            | ProteinTree.protein_tree_node          |
|            402 | NC_TREES                 | NCTree.nc_tree_node                    |
|            501 | GERP_CONSERVATION_SCORE  | ConservationScore.conservation_score   |
+----------------+--------------------------+----------------------------------------+

Each Compara pipeline / resource is associated with a method_link entry. For instance, the EPO multiple alignment are all linked to method_link_id 13, all of the protein trees to method_link_id 401.
Be aware that a single pipeline can produce several resources (for instance: multiple alignments *and* constrained elements, gene trees *and* homologies, etc), and hence use several method_link_id.


3.2 Populate the ncbi_taxa_node and ncbi_taxa_name tables

The easiest way to populate these tables is to take the entries from the current live site
eg

mysqldump -uanonymous -hensembldb.ensembl.org -P5306 --skip-lock-tables ensembl_compara_XXXX ncbi_taxa_node | mysql -u USER -pPASS -h HOST -D DB_NAME

mysqldump -uanonymous -hensembldb.ensembl.org -P5306 --skip-lock-tables ensembl_compara_XXXX ncbi_taxa_name | mysql -u USER -pPASS -h HOST -D DB_NAME

3.3 Add a new species or update the assembly of an existing species

Use the $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl script.

eg
perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl --reg_conf master_reg.conf --compara compara_master --species "otolemur_garnettii"

This command needs a registry configuration file to define the location of the compara_master database and the core database. For an example, see ensembl-compara/docs/master_reg.conf

3.4 Add a new method_link_species_set entry
Use the $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl script

Eg to add a pairwise method_link_species_set_id for species with genome_db_ids of 90 and 124. These must already be in the master database
perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type LASTZ_NET --genome_db_id 90,124 --source "ensembl"  --compara mysql://user:pass@host:port/kb3_ensembl_compara_master 

