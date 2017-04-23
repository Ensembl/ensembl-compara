Import UCSC's *chain* and *net* alignments
==========================================

This README describes the pipeline for importing the chain and net files from UCSC. A statistics page is also produced.

Code API needed and executables
-------------------------------

- bioperl-live (bioperl-1-2-3)
- ensembl
- ensembl-compara
- ensembl-hive
- ensembl-analysis

Code checkout
~~~~~~~~~~~~~

::

      cvs -d :ext:bio.perl.org:/home/repository/bioperl co -r branch-07 bioperl-live
      git clone https://github.com/Ensembl/ensembl.git
      git clone https://github.com/Ensembl/ensembl-compara.git
      git clone https://github.com/Ensembl/ensembl-hive.git
      git clone https://github.com/Ensembl/ensembl-analysis.git

in tcsh

.. code-block:: tcsh

    setenv BASEDIR   /some/path/to/modules
    setenv PERL5LIB  ${BASEDIR}/ensembl/modules:${BASEDIR}/bioperl-live:${BASEDIR}/ensembl-compara/modules:${BASEDIR}/ensembl-hive/modules:${BASEDIR}/ensembl-analysis/modules
    setenv PATH $PATH:${BASEDIR}/ensembl-compara/script/pipeline:${BASEDIR}/ensembl-hive/scripts

in bash

.. code-block:: bash

    BASEDIR=/some/path/to/modules
    PERL5LIB=${BASEDIR}/ensembl/modules:${BASEDIR}/bioperl-live:${BASEDIR}/ensembl-compara/modules:${BASEDIR}/ensembl-hive/modules:${BASEDIR}/ensembl-analysis/modules
    PATH=$PATH:${BASEDIR}/ensembl-compara/scripts/pipeline:${BASEDIR}/ensembl-hive/scripts


Update the master database
--------------------------

The pipeline requires a "master" database. This is a compara database containing information that is required to maintain consistency across several production and release databases. See README-master_database for details on how to create an initial master database.

#. Update genome_db and dnafrag tables with any new species assembly using the update_genome.pl script

   ::

       perl ~/src/ensembl_main/ensembl-compara/scripts/pipeline/update_genome.pl --reg_conf reg.conf --compara compara_master --species "homo_sapiens"

   .. note:: The reg.conf should contain the compara_master and the location of the core database

#. Update method_link_species_set table with new method_link_species_set entry.
   For this pipeline, 1 new method_link_species_set entry ((B)LASTZ_NET) needs to be added to the master using the ensembl-compara/scripts/pipeline/create_mlss.pl script, e.g.

   ::

        perl ~/src/ensembl_main/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type LASTZ_NET --genome_db_id <genome_db_id> --source "ucsc" --compara mysql://user:pass@host:port/ensembl_compara_master --url "http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/"

Download files from UCSC
------------------------

#. Create a directory to store the downloaded files and cd into it

   .. code-block:: bash

      mkdir /lustre/scratch101/ensembl/kb3/scratch/hive/release_66/kb3_hsap_self_ucsc_lastz_66
      cd /lustre/scratch101/ensembl/kb3/scratch/hive/release_66/kb3_hsap_self_ucsc_lastz_66

#. Goto the UCSC downloads directory: http://hgdownload.cse.ucsc.edu/downloads.html

#. Select the reference species eg Human

#. Get the chain and net files by selecting the relevant Pairwise Alignments, e.g.
   to import the human-human self alignments:

   - Select 'Human self alignments'
   - Scroll to the bottom of the page.
   - Download the chain and net files e.g. using wget:

     ::

         wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/hg19.hg19.all.chain.gz
         wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/hg19.hg19.net.gz

#. Uncompress the downloaded files

   ::

        gunzip hg19.hg19.all.chain.gz
        gunzip hg19.hg19.net.gz

#. Get the chromInfo file for each species and the mapping file (if necessary):

   - Make a subdirectory for each species

     ::

         mkdir hsap
   - For instance, for human, select "Annotation database" from the Human Genome page (step (b) above)

     ::

         cd hsap
         wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/database/chromInfo.txt.gz
         wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/database/ctgPos.txt.gz

#. Uncompress the downloaded files

   ::

        gunzip chromInfo.txt.gz
        gunzip ctgPos.txt.gz


Configure the pipeline
----------------------

Modifiy ``ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/ImportUcscChainNet_conf.pm`` file if necessary.
Check that the default_options are set correctly.
Options most likely to need changing are:

:mlss_id:                          It is recommended that this is set on the command line rather than in the conf file
:release:                          Ensembl release
:ensembl_cvs_root_dir:             Root directory of the ensembl checkouts
:output_dir:                       Directory for dumps used for creating coverage statistics

:pipeline_db:                      Production database
:master_db:                        Master database
:staging_loc1,staging_loc1:        Current ensembl core databases
:livemirror_loc:                   Location of previous release core databases

It is recommended the following options are set on the command line

:ref_species:                      Reference species (for nets)
:non_ref_species:                  Non-reference species (will be the same as ref_species for self alignments)
:chain_file:                       Location of downloaded UCSC chain file
:net_file:                         Location of downloaded UCSC net file
:ref_chromInfo_file:               Downloaded UCSC chromInfo file for reference species
:non_ref_chromInfo_file:           Downloaded UCSC chromInfo file for non-reference species
:ref_ucsc_map:                     Downloaded UCSC reference species mapping file (eg ctgPos.txt)
:non_ref_ucsc_map:                 Downloaded UCSC non-reference species mapping file (eg ctgPos.txt)
:config_url:                       Database containing configuration details
:ucsc_url:                         URL to UCSC download page. Used for creation of statistics page

Run init_pipeline.pl
--------------------

Examples:

Human self alignments
~~~~~~~~~~~~~~~~~~~~~

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportUcscChainNet_conf --dbname hsap_hsap_ucsc_test --password *** -mlss_id 1 --ref_species homo_sapiens --non_ref_species homo_sapiens --chain_file hg19.hg19.all.chain --net_file hg19.hg19.net --ref_chromInfo_file hsap/chromInfo.txt --ref_ucsc_map hsap/ctgPos.txt --config_url mysql://user:pass@host:port/pair_aligner_config_db --ucsc_url http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/

Human vs Orangutan alignments
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportUcscChainNet_conf --dbname hsap_pabe_ucsc_test1 --password **** -mlss_id 394 --ref_species homo_sapiens --non_ref_species pongo_abelii --chain_file hg19.ponAbe2.all.chain --net_file hg19.ponAbe2.net --ref_chromInfo_file hsap/chromInfo.txt --non_ref_chromInfo_file pabe/chromInfo.txt --ref_ucsc_map hsap/ctgPos.txt --config_url mysql://user:pass@host:port/pair_aligner_config_db --ucsc_url http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsPonAbe2/

Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output
