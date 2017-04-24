Pairwise alignment
==================

This document describes how to set up the lastz or translated blat pairwise alignment system using the init_pipeline configuration system.

All the scripts are located relative to $ENSEMBL_CVS_ROOT_DIR (location of the GIT checkout)


General description of the pipeline
-----------------------------------

The pipeline consists of a number of stages. Firstly the pairwise executable (lastz or blat) is run. The alignments are then chained according to their location in both genomes and finally nets are produced which chooses the best sub-chain on the reference species in each region. A basic healthcheck is performed to check database consistency and can be compared to a previous release. The final stage is to report some basic statistical information about the alignment (eg coverage).

The base configuration parameters for the pipeline is contained in a Perl module:
``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/PairAligner_conf.pm``

and there are 3 specific configuration files:

:``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Lastz_conf.pm``:
      Default parameters for running Lastz between closely related species, eg between mammals

:``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Lastz_primate_conf.pm``:
      Default parameters for running Lastz between primates

:``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/TBlat_conf.pm``:
      Default parameters for running TBlat between distantly related species eg fish

Necessary software components
-----------------------------

* MySQL 5.1            (or higher)
* Perl 5.6            (or higher)
* Perl DBI API 1.6      (or higher)

EnsEMBL and BioPerl software:

* bioperl-live            : (bioperl-1-2-3)
* ensembl            : core API on which the rest of ensembl APIs are based
* ensembl-compara      : Compara API (data objects, db adaptors, pipeline runnables, pipeline configuration)
* ensembl-analysis      : some of the pipeline runnables live here
* ensembl-hive            : the system to run pipelines

Compiled binaries:

- Lastz: set in Lastz_conf.pm or Lastz_primate_conf.pm
- Blat: set in TBlat_conf.pm
- Jim Kent's programs: (Set in PairAligner_conf.pm)

  - faToNib
  - lavToAxt
  - axtChain
  - chainNet


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

Also refer to the following pages for tips about installation and setting up the environment:

- http://www.ensembl.org/info/docs/api/api_installation.html
- http://www.ensembl.org/info/docs/eHive.html


Configuration of the pipeline
-----------------------------

Nearly all of the pipeline configuration now lives in a base "PipeConfig" file, which is a Perl module:
``ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/PairAligner_conf.pm``

It contains the following subroutines:

:default_options:                
                    Defines customizable options and their default values.
                    In the majority of cases you will only need to modify some of these.
                    Do not rush to run your favourite text editor, as you may also change
                    any of these options from the command line.

:pipeline_create_commands:

                    Defines a list of specific shell commands needed to create a pipeline database.
                    It is unlikely you will need to change it.

:resource_classes:
                    Defines a list of resource classes and corresponding farm-specific parameters for each class.
                    You may need to adjust some of these if running the pipeline on your own farm.

:pipeline_analyses:

                    Defines the structure of the pipeline itself - which tasks to run, in which order, etc.
                    These are the very guts of the pipeline, so make sure you know what you are doing
                    if you are planning to change anything.

There are 3 other Perl modules which inherit from this base class.

:``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Lastz_conf.pm``:
        Default parameters for running Lastz between closely related species eg mammals

:``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Lastz_primate_conf.pm``:
        Default parameters for running Lastz between primates.

:``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/TBlat_conf.pm``:
        Default parameters for running TBlat between distantly related species eg fish

These 3 modules define default parameters suitable for running different pipelines. Values set in these
modules over-ride those set in PairAligner_conf.pm. Values set on the command line will over-ride
any set in these files


PairAligner_conf.pm
~~~~~~~~~~~~~~~~~~~

a) Parameters which may need changing:

:mlss_id:                 It is recommended that this is set on the command line
:dbname:                  It is recommended that this is set on the command line. Note that the user name defined in
                          $ENV{USER} is prepended to dbname so that a dbname of hsap_ptro_lastz will become kb3_hsap_ptro_lastz
:release:                 Ensembl release. Used to create various filenames and default database name
:ensembl_cvs_root_dir:    Root directory of the ensembl checkouts
:faToNib_exe,lavToAxt_exe,axtChain_exe,chainNet_exe:  Location of Jim Kent's executables.
:pipeline_db:                 Production database                  
:master_db:                   Master database
:staging_loc1,staging_loc1:   Current ensembl core databases
:livemirror_loc:              location of previous release core databases
:curr_core_sources_locs:      Location of core databases. These are used to fill in the 'location' field of the genome_db table.

b) If you are not using a master database, remember to unset the master_db parameter:

   ::

      master_db => undef,

Lastz_conf.pm, Lastz_primate_conf.pm or TBlat_conf.pm
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Options you may wish to change:

a) The location of the core databases is defined in PairAligner_conf.pm and defaults to the staging servers. However, the location of the core databases can be defined specifically and the 'curr_core_dbs_locs' set. You must set curr_core_sources_locs to '' to over-ride the default values given in PairAligner_conf.pm. This is useful when using a local core database.

::

    'reference' => {
            -host           => "host_name",
            -port           => port,
            -user           => "user_name",
            -dbname         => "my_human_database",
            -species        => "homo_sapiens"
             },
    'non_reference' => {
                -host           => "host_name",
                -port           => port,
                -user           => "user_name",
                -dbname         => "my_bushbaby_database",
                -species        => "otolemur_garnettii"
              },
    'curr_core_dbs_locs'    => [ $self->o('reference'), $self->o('non_reference') ],
    'curr_core_sources_locs'=> '',

b) ``ref_species``. This defines the which species in the pair to use as the reference. The other is automatically the non-reference.

c) ``default_chunks``. Chunking parameters for the reference and non-reference species.

d) ``pair_aligner_options``

e) ``cellular-component`` restrictions

:``only_cellular_component``: Name of the only cellular-component that should be loaded. Useful when topping up the alignment with MT. Otherwise, leave undefined
:``mix_cellular_components``: By default, the nuclear genome is only aligned against itself, MT only against itself, etc. Switch this option on to allow cross-components alignments

Using the pairwise alignment configuration file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

eg ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/compara-hive-pairaligner-chain-net.conf.example``.
If you are using this configuration file, you can provide only relevant parameters:

The configuration file may define the PAIR_ALIGNER as simply:

::

    { TYPE => PAIR_ALIGNER,
      'reference_collection_name' => 'homo_sapiens lastz',
      'non_reference_collection_name' => 'mus_musculus lastz',
    },

and the ``method_link``, ``analysis_template`` etc parameters can be set globally in the pipeline configuration file eg Lastz_conf.pm. Some parameters such as ``max_parallel_workers`` are ignored and these are set in the PairAligner_conf.pm module.


The master database
-------------------

The master database is used to maintain consistency between release and production databases. A few tables (notably: genome_db, dnafrag and method_link_species_set) are copied directly from the master database into the production database. See :code:`master_database` for details on how to setup and maintain a master database.

To run the pipeline with a master database (recommended) it is necessary to create the master if it does not already exist (see :code:`master_database` for details on how to create an initial master database) and to update it with the new species and method_link_species_set.

1. Update genome_db and dnafrag tables with any new species assembly using the update_genome.pl script

The registry configuration file, reg.conf, should contain the compara_master and the location of the core database

::

    perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl --reg_conf reg.conf --compara compara_master --species "homo_sapiens"

2. Update method_link_species_set table with new method_link_species_set entry

::

   perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --method_link_type LASTZ_NET --genome_db_id 90,124 --source "ensembl" --compara mysql://user:pass@host:port/compara_master_db --url "mysql://user@host:3306/kb3_hsap_ogar_lastz_65"


Run init_pipeline.pl
--------------------

It is possible to set the parameters defined in default_options directly on the command line. You over-ride simple "scalar" parameters by adding "-" to the front e.g. ``-mlss_id`` or ``-dbname`` as in the examples below. If you need to modify second-level values of a "hash option" (such as the '-user' or '-host' of the 'pipeline_db' option), the syntax follows the extended syntax of Getopt::Long, eg ``-pipeline_db -host=myhost -pipeline_db -user=readonly``.

It is possible to run the pipeline in several ways.

1) Using a master database and method_link_species_set_id (mlss_id)

This is the recommended way and will work for a single pairwise alignment
eg. master database, 2 primates

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Lastz_primate_conf -dbname hsap_pabe_lastz_66 -password *** -mlss_id 557 -ref_species homo_sapiens

2) Using a master database and a pairwise alignment configuration file

This should work with several pairwise analyses in the same database
eg

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf -dbname hsap_mmus_rnov_lastz_66 -password *** -conf_file my_conf_file

3) Using a master database and a collection

A collection is a name associated with a set of species. A collection can be populated using the ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl`` script. 
A collection can be used to run several small pairwise pipelines in a single database. If a reference species is defined using the ref_species flag, this reference will be run against all the species in the collection. The collection must additionally contain the reference species.
eg if the ref_species is human and the collection contains human, dog, horse and mouse the following pairs will be created:

- human vs dog
- human vs horse
- human vs mouse

If no ref_species is defined, a triganual matix of all vs all will be created:

- human vs dog
- human vs horse
- human vs mouse
- dog vs horse
- dog vs mouse
- horse vs mouse

Note that it should not matter which species is the reference and which the non-reference since the order cannot be defined.

4) Using no master and a pairwise alignment configuration file

This should work with several pairwise analyses in the same database

5) Using no master and no configuration file

This uses the defaults and species details must be set in the pipeline configuration file and not in a registry configuration file. Will only work for a single pairwise alignment.

Examples
--------

A number of example pipelines have been set up over a small region for human vs mouse and human vs rat.
The master database is set to be a compara release for these tests and the human/mouse method_link_species_set is 601 for LASTZ_NET alignments. Since the examples use lastz, the final LASTZ_NET mlss_id will not be 601. In normal situations, the mlss_id set in the master will correspond to the mlss_id in the pipeline database. 

1) Master database and a method_link_species_set. Define core databases using 'curr_core_sources_locs'.

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LastzMaster_conf -dbname hsap_mmus_pairaligner_test -password *** -dump_dir /location/of/dir/to/dump/nib_files/ -host compara3 -mlss_id 601 --ref_species homo_sapiens

2) Master database and a method_link_species_set. Define core databases using registry file

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LastzMasterReg_conf -dbname hsap_mmus_pairaligner_test -password *** -dump_dir /location/of/dir/to/dump/nib_files/ -host compara3 -mlss_id 601 -reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/reg.conf --ref_species homo_sapiens
 
3) Master database and a method_link_species_set. Define core databases directly in pipeline config file

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LastzMasterCore_conf -dbname hsap_mmus_pairaligner_test -password *** -dump_dir /location/of/dir/to/dump/nib_files/ -host compara3 --mlss_id 601 --ref_species homo_sapiens

4) Master database and a pairwise alignment configuration file. Run human vs mouse and human vs rat alignments.

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LastzMasterConf_conf -dbname hsap_rodent_pairaligner_test  -password *** -conf_file $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/lastz.conf -host compara3

5) No master and pairwise alignment configuration file. Run human vs mouse and human vs rat alignments

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LastzNoMasterConf_conf -dbname hsap_rodent_pairaligner_test  -password *** -conf_file $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/lastz.conf -dump_dir /location/of/dir/to/dump/nib_files/ -host compara3 

6) No master. Define core databases directly in the pipeline config file

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LastzNoMaster_conf -dbname hsap_mmus_pairaligner_test -password *** -dump_dir /location/of/dir/to/dump/nib_files/ -host compara3


Run the beekeeper
-----------------

Details on how to run the beekeeper are given in :doc:`beekeeper`.


Healthchecks and Statistics
---------------------------

A few simple healthchecks are performed and the results are written to the log_message table. Simple coverage statistics are also performed and again, the results are written to the log_message table.
