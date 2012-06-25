=head1 NAME

 Bio::EnsEMBL::Compara::PipeConfig::Example::VegaPairAligner_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. You may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. Make sure that all default_options are set correctly, especially:
        release
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options (eg if doing primate-primate alignments)
        bed_dir if running pairaligner_stats module

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --dbname hsap_ggor_lastz_64 --password <your_password) --mlss_id 536 --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor_nib_files/ --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --password ensembl --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    The PipeConfig file for PairAligner pipeline that should automate most of the tasks. This is in need of further work, especially to deal with multiple pairs of species in the same database. Currently this is dealt with by using the same configuration file as before and the filename should be provided on the command line (--conf_file). 

    You may need to provide a registry configuration file if the core databases have not been added to staging (--reg_conf).

    A single pair of species can be run either by using a configuration file or by providing specific parameters on the command line and using the default values set in this file. On the command line, you must provide the LASTZ_NET mlss which should have been added to the master database (--mlss_id). The directory to which the nib files will be dumped can be specified using --dump_dir or the default location will be used. All the necessary directories are automatically created if they do not already exist. It may be necessary to change the pair_aligner_options default if, for example, doing primate-primate alignments. It is recommended that you provide a meaningful database name (--dbname). The username is automatically prefixed to this, ie -dbname hsap_ggor_lastz_64 will become kb3_hsap_ggor_lastz_64. A basic healthcheck is run and output is written to the job_message table. To write to the pairwise configuration database, you must provide the correct config_url. Even if no config_url is given, the statistics are written to the job_message table.


=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::VegaPairAligner_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},   # inherit the generic ones

    'release'               => '67',
    #'dbname'               => '', #Define on the command line via the conf_file

    # dependent parameters:
    'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
    'pipeline_name'         => 'LASTZ_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

    'pipeline_db' => {                                  # connection parameters
      -host   => 'vegabuild',
      -port   => 5304,
      -user   => 'ottadmin',
      -pass   => $self->o('password'), 
      -dbname => $self->o('ENV', 'USER').'_vega_genomicalignment_20120319_'.$self->o('release').'_testing',
    },

    #nmeed to overwrite the value from ../Lastz_conf.pm
    'masking_options_file' => '',

	#Set for single pairwise mode
#	'mlss_id' => '',

	#Set to use pairwise configuration file
#	'conf_file' => '',

	#directory to dump nib files
    'dump_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/pair_aligner/nib_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

	#min length to dump dna as nib file
#	'dump_min_size' => 11500000, 

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
#	'quick' => 1,

	#Use transactions in pair_aligner and chaining/netting modules (eg LastZ.pm, PairAligner.pm, AlignmentProcessing.pm)
#	'do_transactions' => 1,

        #
	#Default filter_duplicates
	#
#        'window_size' => 1000000,

	#
	#Default pair_aligner
	
    'pair_aligner_exe' => '/software/ensembl/compara/bin/lastz',
        #
	#Default pairaligner config
	#
    'skip_pairaligner_stats' => 0, #skip this module if set to 1
    'output_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/vega_genomicalignment_20120319_'.$self->o('release'),
#    'output_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/vega_genomicalignment_20120319_67_testing',
    };
}

#same as e! but adds a basement queue option in case this is needed (added manually if it is)
sub resource_classes {
    my ($self) = @_;
    return {
	 0 => { -desc => 'v low, 8h',      'LSF' => '-C0 -M100000 -R"select[mem>100] rusage[mem=100]"' },
	 1 => { -desc => 'low, 8h',        'LSF' => '-C0 -M1000000 -R"select[mem>1000] rusage[mem=1000]"' },
	 2 => { -desc => 'default, 8h',    'LSF' => '-C0 -M1800000 -R"select[mem>1800] rusage[mem=1800]"' },
         3 => { -desc => 'himem1, 8h',     'LSF' => '-C0 -M3500000 -R"select[mem>3600] rusage[mem=3600]"' },
         4 => { -desc => 'himem2, 8h',     'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },
         5 => { -desc => 'himem3, notime', 'LSF' => '-C0 -M17000000 -R"select[mem>17000] rusage[mem=17000]" -q "basement"' },
    };
}

#same as e! but excludes (i) populate_new_database (ii) all jobs to do with netting and chaining,

sub pipeline_analyses {
    my ($self) = @_;

    return [
	    {   -logic_name => 'innodbise_table_factory',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='meta' AND engine='MyISAM' ",
				'fan_branch_code' => 2,
			       },
		-input_ids => [{}],
		-flow_into => {
			       2 => [ 'innodbise_table'  ],
			       1 => [ 'get_species_list' ],
			      },
	       -rc_id => 0,
	    },

	    {   -logic_name    => 'innodbise_table',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
				   'sql'         => "ALTER TABLE #table_name# ENGINE='InnoDB'",
				  },
		-hive_capacity => 1,
		-can_be_empty  => 1,
 	        -rc_id => 0,
	    },

	    {   -logic_name    => 'get_species_list',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf',
		-parameters    => {
				  'conf_file' => $self->o('conf_file'),
				  'get_species_list' => 1,
				  }, 
		-wait_for  => [ 'innodbise_table' ],
		-flow_into      => {
				    1 => ['parse_pair_aligner_conf'],
				   },
	       -rc_id => 0,
	    },

	    #Need a conf_file that defines the location of the core dbs
            #Could try enabling the chain and netting...
  	    {   -logic_name    => 'parse_pair_aligner_conf',
  		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf',
  		-parameters    => { 
  				  'conf_file' => $self->o('conf_file'),
  				  'default_chunks' => $self->o('default_chunks'),
  				  'default_pair_aligner' => $self->o('pair_aligner_method_link'),
  				  'default_parameters' => $self->o('pair_aligner_options'),
#  				  'default_chain_output' => $self->o('chain_output_method_link'),
#  				  'default_net_output' => $self->o('net_output_method_link'),
#  				  'default_chain_input' => $self->o('chain_input_method_link'),
#  				  'default_net_input' => $self->o('net_input_method_link'),
				  'mlss_id' => $self->o('mlss_id'),
  				  }, 
		-flow_into => {
			       1 => [ 'create_pair_aligner_jobs'],
			       2 => [ 'chunk_and_group_dna' ], 
			       3 => [ 'create_filter_duplicates_jobs' ],
			       4 => [ 'no_chunk_and_group_dna' ],
			       5 => [ 'create_alignment_chains_jobs' ],
			       6 => [ 'create_alignment_nets_jobs' ],
			       7 => [ 'pairaligner_stats' ],
			       8 => [ 'healthcheck' ],
			       9 => [ 'dump_dna_factory' ],
			      },
	       -rc_id => 0,
  	    },

 	    {  -logic_name => 'chunk_and_group_dna',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna',
 	       -parameters => {
			       'flow_to_store_sequence' => 1,
			      },
 	       -flow_into => {
 	          2 => [ 'store_sequence' ],
 	       },
	       -rc_id => 2,
 	    },
 	    {  -logic_name => 'store_sequence',
 	       -hive_capacity => 100,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence',
 	       -parameters => { },
	       -flow_into => {
 	          -1 => [ 'store_sequence_again' ],
 	       },
	       -rc_id => 2,
  	    },
	    #If fail due to MEMLIMIT, probably due to memory leak, and rerunning with the default memory should be fine.
 	    {  -logic_name => 'store_sequence_again',
 	       -hive_capacity => 100,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence',
 	       -parameters => { }, 
	       -can_be_empty  => 1, 
	       -rc_id => 2,
  	    },
	    {  -logic_name => 'dump_dna_factory',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollectionFactory',
	       -parameters => {
			       'dump_dna'=>1,
			       'dump_min_size'=>1,
			       },
	       -can_be_empty  => 1, 
	       -wait_for => [ 'store_sequence', 'store_sequence_again' ],
	       -rc_id => 1,
	       -flow_into => {
 	          2 => [ 'dump_dna' ],
 	       },
	    },
	    {  -logic_name => 'dump_dna',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection',
	       -parameters => {
			       'dump_dna'=>1,
			       },
	       -can_be_empty  => 1, 
	       -hive_capacity => 10,
	       -rc_id => 1,
	    },
 	    {  -logic_name => 'create_pair_aligner_jobs',  #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs',
 	       -parameters => { },
	       -hive_capacity => 10,
 	       -wait_for => [ 'store_sequence', 'store_sequence_again', 'chunk_and_group_dna', 'dump_dna_factory', 'dump_dna'  ],
	       -flow_into => {
			       1 => [ 'remove_inconsistencies_after_pairaligner' ],
			       2 => [ $self->o('pair_aligner_logic_name')  ],
			   },
	       -rc_id => 1,
 	    },
 	    {  -logic_name => $self->o('pair_aligner_logic_name'),
 	       -module     => $self->o('pair_aligner_module'),
 	       -hive_capacity => $self->o('pair_aligner_hive_capacity'),
 	       -batch_size => $self->o('pair_aligner_batch_size'),
	       -parameters => { 
			       'pair_aligner_exe' => $self->o('pair_aligner_exe'),
			      },
	       -flow_into => {
			      -1 => [ $self->o('pair_aligner_logic_name') . '_himem1' ],  # MEMLIMIT
			     },
	       -rc_id => 2,
	    },
	    {  -logic_name => $self->o('pair_aligner_logic_name') . "_himem1",
 	       -module     => $self->o('pair_aligner_module'),
 	       -hive_capacity => $self->o('pair_aligner_hive_capacity'),
	       -parameters => { 
			       'pair_aligner_exe' => $self->o('pair_aligner_exe'),
			      },
 	       -batch_size => $self->o('pair_aligner_batch_size'),
 	       -program    => $self->o('pair_aligner_program'), 
	       -can_be_empty  => 1, 
	       -rc_id => 3,
	    },
	    {  -logic_name => 'remove_inconsistencies_after_pairaligner',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	       -parameters => { },
 	       -wait_for =>  [ $self->o('pair_aligner_logic_name'), $self->o('pair_aligner_logic_name') . "_himem1" ],
	       -flow_into => {
			      1 => [ 'update_max_alignment_length_before_FD' ],
			     },
	       -rc_id => 0,
	    },
 	    {  -logic_name => 'update_max_alignment_length_before_FD',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -flow_into => {
			      1 => [ 'update_max_alignment_length_after_FD' ],
			     },
	       -rc_id => 0,
 	    },
 	    {  -logic_name => 'create_filter_duplicates_jobs', #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs',
 	       -parameters => { },
 	       -wait_for =>  [ 'update_max_alignment_length_before_FD' ],
	        -flow_into => {
			       2 => [ 'filter_duplicates' ], 
			     },
	       -rc_id => 1,
 	    },
 	     {  -logic_name   => 'filter_duplicates',
 	       -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates',
 	       -parameters    => { 
				  'window_size' => $self->o('window_size') 
				 },
	       -hive_capacity => 50,
	       -batch_size    => 3,
	       -rc_id => 2,
 	    },
 	    {  -logic_name => 'update_max_alignment_length_after_FD',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => {
			       'quick' => $self->o('quick'),
			      },
 	       -wait_for =>  [ 'filter_duplicates' ],
	       -rc_id => 0,
 	    },
          ];
  }


1;
