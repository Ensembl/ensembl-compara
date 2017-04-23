Age of Base
===========

This pipeline will produce a BigBed file which is used the "Age of Base" track. 

General description of the pipeline
-----------------------------------

It uses as input the EPO high coverage mammals alignment and finds the last ancestor which still maintains the reference species base (currently this is human only). 

The bases are coloured depending where in the tree the change occurred.
For example:
If there is a change between human and the human/chimp ancestor, the base is coloured red. 
If there is a change and this corresponds to a human variant, the base is coloured orange.
If there is a change within primates, the base is coloured on a blue scale, darker blue being a more recent change.
If there is a change outside primates, the base is coloured on a grey scale, continuing in intensity from the blue scale.
If there is no change, ie the base is the same throughout the tree, the base is not highlighted. 

Necessary code API and executables
----------------------------------

- ensembl
- ensembl-compara
- ensembl-hive
- bedToBigBed (download from http://genome.ucsc.edu/goldenPath/help/bigBed.html)

Code checkout:

::

      cvs -d :ext:bio.perl.org:/home/repository/bioperl co -r branch-07 bioperl-live
      git clone https://github.com/Ensembl/ensembl.git
      git clone https://github.com/Ensembl/ensembl-compara.git
      git clone https://github.com/Ensembl/ensembl-hive.git

in tcsh

.. code-block:: tcsh

    setenv ENSEMBL_CVS_ROOT_DIR  /some/path/to/modules
    setenv PERL5LIB   ${ENSEMBL_CVS_ROOT_DIR}/bioperl-live:${ENSEMBL_CVS_ROOT_DIR}/ensembl/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/modules
    setenv PATH $PATH:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/script/pipeline:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/scripts

in bash

.. code-block:: bash

    ENSEMBL_CVS_ROOT_DIR=/some/path/to/modules
    PERL5LIB=${ENSEMBL_CVS_ROOT_DIR}/bioperl-live:${ENSEMBL_CVS_ROOT_DIR}/ensembl/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/modules
    PATH=$PATH:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/scripts/pipeline:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/scripts

Configure the pipeline
----------------------

Modifiy ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/BaseAge_conf.pm`` file if necessary.
Check that the default_options are set correctly.

Options most likely to need changing are:

:release:              Ensembl release
:mlss_id:              Mlss_id of the high coverage EPO alignment to be used 
:compara_url:          Database location containing the high coverage EPO alignment 
:variation_url:        Database location of the variation database for the reference species 
:big_bed_exe:          Location of bedToBigBed executable
:big_bed_file:         Filename of bigbed output file
:name:                 Whether to print the ancestral node name ('name') or node_id ('node_id')

:host:                         Production databse host
:pipeline_db:                  Production database details			
:master_db:                    Master database
:staging_loc1,staging_loc1:    Current ensembl core databases
:livemirror_loc:               Location of previous release core databases

We will need to wait for the variation database to be finished before running this pipeline.

The path to the 'bed_dir' is created if it does not already exist. The path to the 'big_bed_file' must exist, ideally it can be created in 'bed_dir'.


Initialize and run the pipeline
-------------------------------

::

     init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::BaseAge_conf --password <your_password> --mlss_id <high-coverage EPO mammals mlss_id> -host <production-host> --bed_dir <output_directory> --big_bed_file <final_big_bed_file>

Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output
