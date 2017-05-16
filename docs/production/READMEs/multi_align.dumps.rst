Dump of Whole-genome alignments
===============================

This README describes how to run the DumpMultiAlign pipeline.

The dumps are grouped by the toplevel regions of the reference species.
Alignments not containing the reference species are written to files called
\*.other\_\*. Each file contains split_size alignments (default 200).
Alignments containing duplications in the reference species are dumped once
per duplicated segment.

The pipeline will create all the necessary jobs, run scripts/dumps/DumpMultiAlign.pl, optionally run emf2maf, compress, create the MD5SUM and also create a stanadard readme file. The pipeline looks something like::

                  InitJobs           Readme
             /       |         \
 CreateChrJobs CreateSuperJobs CreateOtherJobs
              \      |         /
               DumpMultiAlign
                     |     \
                     |     emf2maf
                     |     /
                  Compress
                     |
		   MD5SUM

You need a reg_conf file containing the location of the EnsEMBL core sequences and the location of the compara database containing the alignments to dump.

All the scripts are located relative to $ENSEMBL_CVS_ROOT_DIR (location of the GIT checkout)

#. Edit ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/DumpMultiAlign_conf.pm``

   The location of the compara and core databases containing the alignments
   can be defined using the parameter 'reg_conf' and 'compara_db'. Defaults
   have been set in the DumpMultiAlign_conf.pm. Most options likely to change
   are done on the command line.

   Options most likely to need chaging are:

   :compara_db:   Where the alignments are. Either a URL or a name found in the Registry
   :reg_conf:     Registry configuration file
   :format:       Many formats are accepted. "emf" (default), "maf", and "emf+maf" are the most common
   :export_dir:   Where to dump files. The pipeline will create 1 directory per alignment there

   Other options are:

   :split_size:           Maximum number of blocks per file (default: 200)
   :masked_seq:           As in DumpMultiAlign.pl (0 for unmasked, 1 for soft-masked (default), 2 for hard-masked)
   :split_by_chromosome:  If set to 1, the files are split by chromosome name and coordinate system. Otherwise, createOtherJobs randomly bins the alignment blocks into chunks
   :make_tar_archive:     If set to 1, will make a compressed tar archive of a directory of uncompressed files. Otherwise, there will be a directory of compressed files
   :method_link_types:    In case you only want to dump a particular kind of alignments

#. Run init_pipeline.pl

   ::

       init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db mysql://ensro@comparaX/msa_db_to_dump --export_dir where/the/dumps/will/be/
       init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db mysql://ensro@ens-staging1/ensembl_compara_80 --reg_conf path/to/production_reg_conf.pl
       init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::DumpMultiAlign_conf --host comparaY --compara_db compara_prev --reg_conf path/to/production_reg_conf.pl --format maf --method_link_types EPO


#. Advanced usage

   To tell the pipeline to dump a specific alignment, you can add --mlss_id XXX to the init_pipeline.pl command

