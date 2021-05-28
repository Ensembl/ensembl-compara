EPO alignment with additional genomes
=======================================

This README describes how to set up the EPO Extended aligner system using the init_pipeline configuration system.

General description of the pipeline
-----------------------------------

This pipeline involves mapping additional mammal genomes via lastz pairwise alignments (with shared reference genomes) to an existing mammal EPO multiple alignment.

Necessary code API and executables
----------------------------------

- bioperl-live (bioperl-1-2-3)
- ensembl
- ensembl-compara
- ensembl-hive

Code checkout
~~~~~~~~~~~~~

::

      cvs -d :ext:bio.perl.org:/home/repository/bioperl co -r branch-07 bioperl-live
      git clone https://github.com/Ensembl/ensembl.git
      git clone https://github.com/Ensembl/ensembl-compara.git
      git clone https://github.com/Ensembl/ensembl-hive.git

in tcsh

.. code-block:: tcsh

    setenv BASEDIR   /some/path/to/modules
    setenv PERL5LIB  ${BASEDIR}/ensembl/modules:${BASEDIR}/bioperl-live:${BASEDIR}/ensembl-compara/modules:${BASEDIR}/ensembl-hive/modules
    setenv PATH $PATH:${BASEDIR}/ensembl-compara/script/pipeline:${BASEDIR}/ensembl-hive/scripts

in bash

.. code-block:: bash

    BASEDIR=/some/path/to/modules
    PERL5LIB=${BASEDIR}/ensembl/modules:${BASEDIR}/bioperl-live:${BASEDIR}/ensembl-compara/modules:${BASEDIR}/ensembl-hive/modules
    PATH=$PATH:${BASEDIR}/ensembl-compara/scripts/pipeline:${BASEDIR}/ensembl-hive/scripts

Update the master database
--------------------------

This pipeline requires a compara "master" database containing information that maintains consistency across several production and release databases. See README-master_database for details on how to create an initial master database.

#. Update genome_db and dnafrag tables with any new species assembly using the update_genome.pl script.
   The reg.conf should contain the compara_master and the location of the core database

   ::

       perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl --reg_conf reg.conf --compara compara_master --species "homo_sapiens"

#. Update method_link_species_set table with new method_link_species_set entry.
   This must be added after the mlss_id for the high coverage EPO pipeline else the internal ids will not be set correctly.

   For this pipeline, 3 new method_link_species_set entries (EPO_EXTENDED,GERP_CONSERVATION_SCORE and GERP_CONSTRAINED_ELEMENT) need to be added to the master using the ``$ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl`` script.

   ::

       perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type EPO_EXTENDED --genome_db_id <list_of_genome_db_ids>  --source "ensembl" --compara mysql://user:pass@host:port/compara_master_db
       perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type GERP_CONSERVATION_SCORE --genome_db_id <list_of_genome_db_ids>  --source "ensembl" --compara mysql://user:pass@host:port/compara_master_db
       perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type GERP_CONSTRAINED_ELEMENT --genome_db_id <list_of_genome_db_ids>  --source "ensembl" --compara mysql://user:pass@host:port/compara_master_db

Configure the pipeline
----------------------

Modifiy ``$ENSEMBL_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/EpoExtended_conf.pm`` file if necessary.
Check that the default_options are set correctly.
Options most likely to need changing are:

It is recommended that the mlss_id entries are set on the command line rather than in the conf file

:ext_mlss_id:                  mlss_id of the EPO Extended alignments
:mlss_id:                      mlss_id of the EPO alignments
:ce_mlss_id:                   mlss_id of the constrained elements
:cs_mlss_id:                   mlss_id of the conservation scores

:release:                      Ensembl release
:prev_release:                 Previous ensembl release
:ensembl_root_dir:             Root directory of the ensembl checkouts
:work_dir:                     Directory for writing files

:pairwise_exception_location:  Location of new pairwise alignments which are not in the release compara database ie new for this release
:pipeline_db:                  Production database
:master_db:                    Master database
:epo_db:                       Location of database containing high coverage alignments. It is recommended this is set on the command line to ensure this is updated
:live_compara_db:              Release compara database containing pairwise alignments, ie those not rerun for this release
:staging_loc1,staging_loc1:    Current ensembl core databases
:livemirror_loc:               Location of previous release core databases

:gerp_exe_dir:                 Location of gerp executable directory

Initialize and run the pipeline
-------------------------------

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EpoExtended_conf --password <your_password> --work_dir <working_directory> --epo_db mysql://user@host:port/high_coverage_epo_db

Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output
