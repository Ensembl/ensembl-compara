Mercator-Pecan multiple-alignment
=================================

This README describes how to set up the multiple aligner system using the init_pipeline configuration system. 
This pipeline has only been tested for the Mercator and Pecan combination. 

All the scripts are located relative to $ENSEMBL_CVS_ROOT_DIR (location of the GIT checkout)

General description of the pipeline
-----------------------------------

The pipeline consists of running the orthologous map creator, Mercator and the multiple aligner program, Pecan. Where possible, blast hits from a previous run of the pipeline are re-used ie between species that have not changed.
Jobs failing due to memory are automatically rescheduled to run again with increased memory resources. 
A basic healthcheck is performed to check database consistency and compared with a previous release.

The configuration file for the pipeline is:
``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/MercatorPecan_conf.pm``

Code API needed and executables
-------------------------------

- bioperl-live (bioperl-1-2-3)
- ensembl
- ensembl-compara
- ensembl-hive
- ensembl-analysis

Executables
~~~~~~~~~~~

:mercator:
  ``mercator_exe`` : Mercator

:ncbi blast:
  ``blast_bin_dir`` : NCBI-Blast 2.2.27+

:gerp:
  ``gerp_exe_dir`` : GERP v2.1


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

#. Update genome_db and dnafrag tables with any new species assembly using the update_genome.pl script.
   The reg.conf should contain the compara_master and the location of the core database

   ::

       perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl --reg_conf reg.conf --compara compara_master --species "homo_sapiens"

#. Update method_link_species_set table with new method_link_species_set entry.
   For this pipeline, 3 new method_link_species_set entries (PECAN,GERP_CONSERVATION_SCORE and GERP_CONSTRAINED_ELEMENT) need to be added to the master using the ``ensembl-compara/scripts/pipeline/create_mlss.pl`` script.

   ::

       perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type PECAN --genome_db_id <list_of_genome_db_ids>  --source "ensembl" --compara mysql://user:pass@host:port/compara_master
       perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type GERP_CONSERVATION_SCORE --genome_db_id <list_of_genome_db_ids>  --source "ensembl" --compara mysql://user:pass@host:port/compara_master
       perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type GERP_CONSTRAINED_ELEMENT --genome_db_id <list_of_genome_db_ids>  --source "ensembl" --compara mysql://user:pass@host:port/compara_master


Configure the pipeline
----------------------

Modifiy ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/MercatorPecan_conf.pm`` file if necessary.
Check that the default_options are set correctly.
Options most likely to need changing are:

:mlss_id, ce_mlss_id, cs_mlss_id:  It is recommended that these are set on the command line rather than in the conf file
:release:                          Ensembl release
:ensembl_cvs_root_dir:             Root directory of the ensembl checkouts
:work_dir:                         Directory for writing files needed by blast and mercator.
:jar_file:                         Location of Pecan jar file
:gerp_exe_dir:                     Location of gerp executable directory
:mercator_exe:                     Location of mercator executable
:blast_bin_dir:                    Location of ncbi blast binaries
:master_db_name:                   Name of "master" database

:pipeline_db:                      Production database
:master_db:                        Master database
:staging_loc1,staging_loc1:        Current ensembl core databases
:livemirror_loc:                   Location of previous release core databases
:reuse_db:                         Previous pecan production database

Initialize and run the pipeline
-------------------------------

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MercatorPecan_conf -password <your_password> -mlss_id <pecan_mlss_id> --ce_mlss_id <constrained_element_mlss_id> --cs_mlss_id <conservation_score_mlss_id>

Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

