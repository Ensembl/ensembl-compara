Whole Genome Synteny pipeline
=============================

This document describes how to set up the synteny pipeline for whole genome alignments only. Currently there is no support for homologues.

All the scripts are located relative to $ENSEMBL_CVS_ROOT_DIR (location of the *GIT* checkout).
Further details can be in the file ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/synteny/README``

General description of the pipeline
-----------------------------------

The pipeline consists of creating a set of gff format files, one per chromosome, running the BuildSyteny java program and concatenating the resultant files to produce one final output file which can be imported into a compara database.

Dumping gff files
~~~~~~~~~~~~~~~~~

Generally syntenies are only calculated for chromosomes that have a corresponding karyotype.
This can be over-ridden by setting the coord_system_name and the force flag to 1.

The whole genome alignments are dumped in gff format using the
``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl`` script for a given chromosome.
For most alignments we use the default level 1 LASTZ_NET alignments but for human vs chimp we use both level 1 and level 2.
Setting the level parameter to 1 will select level 1 alignments whilst setting it to 2 will select both level 1 and level 2 alignments.
The module will write out all the matches into files named called 1.syten.gff, 2.syten.gff etc.

BuildSynteny program
~~~~~~~~~~~~~~~~~~~~

This program uses two parameters to define the syntenic regions. The first one, the maxDist, is used
to define the maximum gap allowed between alignments within a syntenic block. The second one, the minDist,
is the minimum length a syntenic block must have, shorter blocks are discarded. Both parameters can be set
identically or individually for both genomes.

The syntenic blocks are defined in two steps. In the first one, links (alignments) are grouped if they are in
synteny, there is no other link breaking the synteny and the distance between the links is smaller than
twice the maxDist parameter. In the second step, groups are grouped in syntenic block but this time, up to
two other groups breaking the synteny are allowed (these are the internum lines found in the output which can
be safely discarded) and the maximum distance between groups is 30 times the the maxDist parameter.

The orient parameter is always set to 'false' for mammals but maybe omitted for worms eg elegans/briggsae.

Concatenation of files
~~~~~~~~~~~~~~~~~~~~~~

The final stage of the pipeline is to concatenate all the results into a single file called, for example,
all.100000.100000.BuildSynteny.

Loading the data into a compara database
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The concatenated file is loaded into the synteny_region and dnafrag_region table of the pipeline_db.

Coverage statistics
~~~~~~~~~~~~~~~~~~~

Coverage statistics are calculated on the synteny data.
The results are stored in the method_link_species_set_tag table.


Code API needed
---------------

- ensembl
- ensembl-compara
- ensembl-hive

Code checkout:

::

      git clone https://github.com/Ensembl/ensembl.git
      git clone https://github.com/Ensembl/ensembl-compara.git
      git clone https://github.com/Ensembl/ensembl-hive.git

in tcsh

.. code-block:: tcsh

    setenv ENSEMBL_CVS_ROOT_DIR  /some/path/to/modules
    setenv PERL5LIB   ${ENSEMBL_CVS_ROOT_DIR}/ensembl/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/modules
    setenv PATH $PATH:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/script/pipeline:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/scripts

in bash

.. code-block:: bash

    ENSEMBL_CVS_ROOT_DIR=/some/path/to/modules
    PERL5LIB=${ENSEMBL_CVS_ROOT_DIR}/ensembl/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/modules
    PATH=$PATH:${ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/scripts/pipeline:${ENSEMBL_CVS_ROOT_DIR}/ensembl-hive/scripts

Configure the pipeline
----------------------

Modifiy ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Synteny_conf.pm`` file if necessary.
Check that the default_options are set correctly. Alternatively, set the parameters on the command line.
Options most likely to need changing are:

:release:           Ensembl release
:host:              MySQL server name
:synteny_dir:       Location of directory to write output files
:compara_url:       URL of the pairwise database
:pairwise_mlss_id:  method_link_species_set id of the LASTZ_NET alignment
:synteny_mlss_id:   method_link_species_set id of the SYNTENY data which will be generated.
:ref_species:       reference species of the LASTZ_NET alignment

Initialize and run the pipeline
-------------------------------
For example:

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Synteny_conf --password <your_password> --ref_species oryzias_latipes  --pairwise_mlss_id 764 --synteny_mlss_id 10109  --compara_url "mysql://ensro@compara4:3306/sf5_olat_tnig_lastz_80"

Make sure you have either your JAVA_HOME variable set

.. code-block:: bash

 JAVA_HOME=/usr/bin/java
 export JAVA_HOME

or that the java executable is in your PATH

Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output
