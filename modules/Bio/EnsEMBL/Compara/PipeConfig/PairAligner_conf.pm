=head1 NAME

 Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf

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

package Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        #'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/src/ensembl_main/', 
        'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'}, 

	'release'               => '70',
        'release_suffix'        => '',    # an empty string by default, a letter otherwise
	#'dbname'               => '', #Define on the command line. Compara database name eg hsap_ggor_lastz_64

         # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
        'pipeline_name'         => 'LASTZ_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'), 
            -dbname => $ENV{USER}.'_'.$self->o('dbname'),    
        },

	'master_db' => 'mysql://ensro@compara1/sf5_ensembl_compara_master',

	'staging_loc1' => {
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },
        'staging_loc2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },  
	 'livemirror_loc' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => 70,
        },

	'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
	#'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],
	'curr_core_dbs_locs'        => '', #if defining core dbs with config file. Define in Lastz_conf.pm or TBlat_conf.pm

	# executable locations:
	'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",
	'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
	'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",
	'update_config_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/update_config_database.pl",
	'create_pair_aligner_page_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl",
	'faToNib_exe' => '/software/ensembl/compara/bin/faToNib',
	'lavToAxt_exe' => '/software/ensembl/compara/bin/lavToAxt',
	'axtChain_exe' => '/software/ensembl/compara/bin/axtChain',
	'chainNet_exe' => '/software/ensembl/compara/bin/chainNet',

	#Set for single pairwise mode
	'mlss_id' => '',

	#Set to use pairwise configuration file
	'conf_file' => '',

	#Set to use registry configuration file
	'reg_conf' => '',

	#Reference species (if not using pairwise configuration file)
	'ref_species' => 'homo_sapiens',

	#directory to dump nib files
	'dump_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/pair_aligner/nib_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

        #include MT chromosomes if set to 1 ie MT vs MT only else avoid any MT alignments if set to 0
        'include_MT' => 1,
	
	#include only MT, in some cases we only want to align MT chromosomes (set to 1 for MT only and 0 for normal mode). 
	#Also the name of the MT chromosome in the db must be the string "MT".    
	'MT_only' => 0, # if MT_only is set to 1, then include_MT must also be set to 1

	#min length to dump dna as nib file
	'dump_min_size' => 11500000, 

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
	'quick' => 1,

	#
	#Default chunking parameters
	#
         'default_chunks' => {#human example
			     'reference'   => {'chunk_size' => 30000000,
					       'overlap'    => 0,
					       'include_non_reference' => -1, #1  => include non_reference regions (eg human assembly patches)
					                                      #0  => do not include non_reference regions
					                                      #-1 => auto-detect (only include non_reference regions if the non-reference species is high-coverage 
					                                      #ie has chromosomes since these analyses are the only ones we keep up-to-date with the patches-pipeline)

#Human specific masking
#					       'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec"
                                              },
			     #non human example
#   			    'reference'     => {'chunk_size'      => 10000000,
#   						'overlap'         => 0,
#   						'masking_options' => '{default_soft_masking => 1}'},
   			    'non_reference' => {'chunk_size'      => 10100000,
   						'group_set_size'  => 10100000,
   						'overlap'         => 100000,
   						'masking_options' => '{default_soft_masking => 1}'},
   			    },
	    
	#Use transactions in pair_aligner and chaining/netting modules (eg LastZ.pm, PairAligner.pm, AlignmentProcessing.pm)
	'do_transactions' => 1,

        #
	#Default filter_duplicates
	#
        #'window_size' => 1000000,
        'window_size' => 10000,
	'filter_duplicates_rc_name' => '1Gb',
	'filter_duplicates_himem_rc_name' => '3.6Gb',

	#
	#Default pair_aligner
	#
   	'pair_aligner_method_link' => [1001, 'LASTZ_RAW'],
	'pair_aligner_logic_name' => 'LastZ',
	'pair_aligner_program' => 'lastz',
	'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ',
	'pair_aligner_options' => 'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', #hsap vs mammal
	'pair_aligner_hive_capacity' => 100,
	'pair_aligner_batch_size' => 3,

        #
        #Default chain
        #
	'chain_input_method_link' => [1001, 'LASTZ_RAW'],
	'chain_output_method_link' => [1002, 'LASTZ_CHAIN'],

	 #linear_gap=>medium for more closely related species, 'loose' for more distant
	'linear_gap' => 'medium',

  	'chain_parameters' => {'max_gap'=>'50','linear_gap'=> $self->o('linear_gap'), 'faToNib' => $self->o('faToNib_exe'), 'lavToAxt'=> $self->o('lavToAxt_exe'), 'axtChain'=>$self->o('axtChain_exe')}, 
  	'chain_batch_size' => 1,
  	'chain_hive_capacity' => 20,

	#
        #Default set_internal_ids
        #
	'skip_set_internal_ids' => 0,  #skip this module if set to 1

        #
        #Default net 
        #
	'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
        'net_output_method_link' => [16, 'LASTZ_NET'],
        'net_ref_species' => $self->o('ref_species'),  #default to ref_species
  	'net_parameters' => {'max_gap'=>'50', 'chainNet'=>$self->o('chainNet_exe')},
  	'net_batch_size' => 1,
  	'net_hive_capacity' => 20,

	#
	#Default healthcheck
	#
	'previous_db' => $self->o('livemirror_loc'),
	'prev_release' => 0,   # 0 is the default and it means "take current release number and subtract 1"    
	'max_percent_diff' => 20,
	'do_pairwise_gabs' => 1,
	'do_compare_to_previous_db' => 1,

        #
	#Default pairaligner config
	#
	'skip_pairaligner_stats' => 0, #skip this module if set to 1
#	'bed_dir' => '/nfs/ensembl/compara/dumps/bed/',
	'bed_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/pair_aligner/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',
	'output_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/pair_aligner/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
       'mkdir -p '.$self->o('dump_dir'), #Make dump_dir directory
       'mkdir -p '.$self->o('output_dir'), #Make dump_dir directory
       'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
    ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
	    'pipeline_name' => $self->o('pipeline_name'), #This must be defined for the beekeeper to work properly
	    'do_transactions' => $self->o('do_transactions'),
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb' => { 'LSF' => '-C0 -M100000 -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'   => { 'LSF' => '-C0 -M1000000 -R"select[mem>1000] rusage[mem=1000]"' },
            '1.8Gb' => { 'LSF' => '-C0 -M1800000 -R"select[mem>1800] rusage[mem=1800]"' },
            '3.6Gb' => { 'LSF' => '-C0 -M3600000 -R"select[mem>3600] rusage[mem=3600]"' },
    };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
	    # ---------------------------------------------[Turn all tables except 'genome_db' to InnoDB]---------------------------------------------
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
	       -rc_name => '100Mb',
	    },

	    {   -logic_name    => 'innodbise_table',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
				   'sql'         => "ALTER TABLE #table_name# ENGINE='InnoDB'",
				  },
		-hive_capacity => 1,
		-can_be_empty  => 1,
 	        -rc_name => '100Mb',
	    },

	    {   -logic_name    => 'get_species_list',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf',
		-parameters    => { 
				  #'compara_url' => $self->dbconn_2_url('master_db'),
				   'master_db' => $self->o('master_db'),
				  'reg_conf'  => $self->o('reg_conf'),
				  'conf_file' => $self->o('conf_file'),
				  'core_dbs' => $self->o('curr_core_dbs_locs'),
				  'get_species_list' => 1,
				  }, 
		-wait_for  => [ 'innodbise_table' ],
		-flow_into      => {
				    1 => ['populate_new_database'],
				   },
	       -rc_name => '100Mb',
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'mlss_id'        => $self->o('mlss_id'),
				  'reg_conf'        => $self->o('reg_conf'),
#				  'cmd'            => "#program# --master " . $self->dbconn_2_url('master_db') . " --MT_only " . $self->o('MT_only') . " --new " . $self->dbconn_2_url('pipeline_db') . " --species #speciesList# --mlss #mlss_id# --reg-conf #reg_conf# ",
				  #If no master set, then use notation below
				  'cmd'            => "#program# --master " . $self->o('master_db') . " --new " . $self->dbconn_2_url('pipeline_db') . " --MT_only " . $self->o('MT_only') . " --species #speciesList# --mlss #mlss_id# --reg-conf #reg_conf# ",
				 },
	       -flow_into => {
			      1 => [ 'parse_pair_aligner_conf' ],
			     },
	       -rc_name => '1Gb',
	    },

	    #Need reg_conf, conf_file or registry_dbs to define the location of the core dbs
	    # The work of load_genomedb is currently done by parse_pair_aligner_conf but should be moved to LoadOneGenomeDB really
  	    {   -logic_name    => 'parse_pair_aligner_conf',
  		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf',
  		-parameters    => { 
  				  'reg_conf'  => $self->o('reg_conf'),
  				  'conf_file' => $self->o('conf_file'),
				  'ref_species' => $self->o('ref_species'),
				  'dump_dir' => $self->o('dump_dir'),
  				  'default_chunks' => $self->o('default_chunks'),
  				  'default_pair_aligner' => $self->o('pair_aligner_method_link'),
  				  'default_parameters' => $self->o('pair_aligner_options'),
  				  'default_chain_output' => $self->o('chain_output_method_link'),
  				  'default_net_output' => $self->o('net_output_method_link'),
  				  'default_chain_input' => $self->o('chain_input_method_link'),
  				  'default_net_input' => $self->o('net_input_method_link'),
				  'net_ref_species' => $self->o('net_ref_species'),
				  'mlss_id' => $self->o('mlss_id'),
				  'registry_dbs' => $self->o('curr_core_sources_locs'),
				  'core_dbs' => $self->o('curr_core_dbs_locs'),
				  'master_db' => $self->o('master_db'),
				  'do_pairwise_gabs' => $self->o('do_pairwise_gabs'), #healthcheck options
				  'do_compare_to_previous_db' => $self->o('do_compare_to_previous_db'), #healthcheck options
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
	       -rc_name => '100Mb',
  	    },

 	    {  -logic_name => 'chunk_and_group_dna',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna',
 	       -parameters => {
			       'MT_only' => $self->o('MT_only'),
			       'flow_to_store_sequence' => 1,
			      },
 	       -flow_into => {
 	          2 => [ 'store_sequence' ],
 	       },
	       -rc_name => '1.8Gb',
 	    },
 	    {  -logic_name => 'store_sequence',
 	       -hive_capacity => 100,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence',
 	       -parameters => { },
	       -flow_into => {
 	          -1 => [ 'store_sequence_again' ],
 	       },
	       -rc_name => '1.8Gb',
  	    },
	    #If fail due to MEMLIMIT, probably due to memory leak, and rerunning with the default memory should be fine.
 	    {  -logic_name => 'store_sequence_again',
 	       -hive_capacity => 100,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence',
 	       -parameters => { }, 
	       -can_be_empty  => 1, 
	       -rc_name => '1.8Gb',
  	    },
	    {  -logic_name => 'dump_dna_factory',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollectionFactory',
	       -parameters => {
			       'dump_dna'=>1,
			       'dump_min_size'=>1,
			       },
	       -can_be_empty  => 1, 
	       -wait_for => [ 'store_sequence', 'store_sequence_again' ],
	       -rc_name => '1Gb',
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
	       -rc_name => '1Gb',
	    },
 	    {  -logic_name => 'create_pair_aligner_jobs',  #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs',
 	       -parameters => { 
                               'include_MT' => $self->o('include_MT'),
                              },
	       -hive_capacity => 10,
 	       -wait_for => [ 'store_sequence', 'store_sequence_again', 'chunk_and_group_dna', 'dump_dna_factory', 'dump_dna'  ],
	       -flow_into => {
			       1 => [ 'remove_inconsistencies_after_pairaligner' ],
			       2 => [ $self->o('pair_aligner_logic_name')  ],
			   },
	       -rc_name => '1Gb',
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
	       -rc_name => '1.8Gb',
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
	       -rc_name => '3.6Gb',
	    },
	    {  -logic_name => 'remove_inconsistencies_after_pairaligner',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	       -parameters => { },
 	       -wait_for =>  [ $self->o('pair_aligner_logic_name'), $self->o('pair_aligner_logic_name') . "_himem1" ],
	       -flow_into => {
			      1 => [ 'update_max_alignment_length_before_FD' ],
			     },
	       -rc_name => '100Mb',
	    },
 	    {  -logic_name => 'update_max_alignment_length_before_FD',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -flow_into => {
			      1 => [ 'update_max_alignment_length_after_FD' ],
			     },
	       -rc_name => '100Mb',
 	    },
 	    {  -logic_name => 'create_filter_duplicates_jobs', #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs',
 	       -parameters => { },
 	       -wait_for =>  [ 'update_max_alignment_length_before_FD' ],
	        -flow_into => {
			       2 => [ 'filter_duplicates' ], 
			     },
	       -rc_name => '1Gb',
 	    },
 	     {  -logic_name   => 'filter_duplicates',
 	       -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates',
 	       -parameters    => { 
				  'window_size' => $self->o('window_size') 
				 },
	       -hive_capacity => 50,
	       -batch_size    => 3,
	       -flow_into => {
			       -1 => [ 'filter_duplicates_himem' ], # MEMLIMIT
			     },
	       -rc_name => $self->o('filter_duplicates_rc_name'),
 	    },
	    {  -logic_name   => 'filter_duplicates_himem',
 	       -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates',
 	       -parameters    => { 
				  'window_size' => $self->o('window_size') 
				 },
	       -hive_capacity => 50,
	       -batch_size    => 3,
	       -can_be_empty  => 1, 
	       -rc_name => $self->o('filter_duplicates_himem_rc_name'),
 	    },
 	    {  -logic_name => 'update_max_alignment_length_after_FD',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => {
			       'quick' => $self->o('quick'),
			      },
 	       -wait_for =>  [ 'filter_duplicates', 'filter_duplicates_himem' ],
	       -rc_name => '100Mb',
 	    },
#
#Second half of the pipeline
#

 	    {  -logic_name => 'no_chunk_and_group_dna',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna',
 	       -parameters => {
			       'flow_to_store_sequence' => 0,
			      },
	       -flow_into => {
			      1 => [ 'dump_large_nib_for_chains_factory' ],
			     },
	       -wait_for  => ['update_max_alignment_length_after_FD' ],
	       -rc_name => '1.8Gb',
 	    },
 	    {  -logic_name => 'dump_large_nib_for_chains_factory',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollectionFactory',
 	       -parameters => {
			       'faToNib_exe' => $self->o('faToNib_exe'),
			       'dump_nib'=>1,
			       'dump_min_size' => $self->o('dump_min_size'),
			      },
	       -hive_capacity => 1,
	       -flow_into => {
			      2 => [ 'dump_large_nib_for_chains' ],
			     },
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'dump_large_nib_for_chains',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection',
 	       -parameters => {
			       'faToNib_exe' => $self->o('faToNib_exe'),
			       'dump_nib'=>1,
			      },
	       -can_be_empty  => 1, 
	       -hive_capacity => 10,
	       -flow_into => {
			      -1 => [ 'dump_large_nib_for_chains_himem' ],  # MEMLIMIT
			     },
	       -rc_name => '1.8Gb',
 	    },
	    {  -logic_name => 'dump_large_nib_for_chains_himem',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection',
 	       -parameters => {
			       'faToNib_exe' => $self->o('faToNib_exe'),
			       'dump_nib'=>1,
			      },
	       -hive_capacity => 10,
	       -can_be_empty  => 1, 
	       -rc_name => '3.6Gb',
 	    },
 	    {  -logic_name => 'create_alignment_chains_jobs',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentChainsJobs',
		-parameters => { }, 
		-flow_into => {
#			      1 => [ 'update_max_alignment_length_after_chain' ],
			      1 => [ 'remove_inconsistencies_after_chain' ],
			      2 => [ 'alignment_chains' ],
			     },
 	       -wait_for => [ 'dump_large_nib_for_chains_factory', 'dump_large_nib_for_chains', 'dump_large_nib_for_chains_himem' ],
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'alignment_chains',
 	       -hive_capacity => $self->o('chain_hive_capacity'),
 	       -batch_size => $self->o('chain_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
 	       -parameters => $self->o('chain_parameters'),
	       -flow_into => {
			      -1 => [ 'alignment_chains_himem' ],  # MEMLIMIT
			     },
	       -rc_name => '1.8Gb',
 	    },
	    {  -logic_name => 'alignment_chains_himem',
 	       -hive_capacity => $self->o('chain_hive_capacity'),
 	       -batch_size => $self->o('chain_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
 	       -parameters => $self->o('chain_parameters'),
	       -can_be_empty  => 1, 
	       -rc_name => '3.6Gb',
 	    },
	    {
	     -logic_name => 'remove_inconsistencies_after_chain',
	     -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	     -flow_into => {
			      1 => [ 'update_max_alignment_length_after_chain' ],
			   },
	     -wait_for =>  [ 'alignment_chains', 'alignment_chains_himem' ],
	     -rc_name => '100Mb',
	    },
	    {  -logic_name => 'update_max_alignment_length_after_chain',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -rc_name => '100Mb',
 	    },
 	    {  -logic_name => 'create_alignment_nets_jobs',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentNetsJobs',
 	       -parameters => { },
		-flow_into => {
#			       1 => [ 'set_internal_ids', 'update_max_alignment_length_after_net' ],
			       1 => [ 'set_internal_ids', 'remove_inconsistencies_after_net' ],
			       2 => [ 'alignment_nets' ],
			      },
 	       -wait_for => [ 'update_max_alignment_length_after_chain' ],
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'set_internal_ids',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIds',
 	       -parameters => {
			       'tables' => [ 'genomic_align_block', 'genomic_align' ],
			       'skip' => $self->o('skip_set_internal_ids'),
			      },
	       -rc_name => '100Mb',
 	    },
 	    {  -logic_name => 'alignment_nets',
 	       -hive_capacity => $self->o('net_hive_capacity'),
 	       -batch_size => $self->o('net_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
 	       -parameters => $self->o('net_parameters'),
	       -flow_into => {
			      -1 => [ 'alignment_nets_himem' ],  # MEMLIMIT
			     },
	       -wait_for => [ 'set_internal_ids' ],
	       -rc_name => '1Gb',
 	    },
	    {  -logic_name => 'alignment_nets_himem',
 	       -hive_capacity => $self->o('net_hive_capacity'),
 	       -batch_size => $self->o('net_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
 	       -parameters => $self->o('net_parameters'),
	       -can_be_empty  => 1, 
	       -rc_name => '1.8Gb',
 	    },
	    {
	     -logic_name => 'remove_inconsistencies_after_net',
	     -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	     -flow_into => {
			       1 => [ 'update_max_alignment_length_after_net' ],
			   },
 	       -wait_for =>  [ 'alignment_nets', 'alignment_nets_himem' ],
	       -rc_name => '100Mb',
	    },
 	    {  -logic_name => 'update_max_alignment_length_after_net',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -rc_name => '100Mb',
 	    },
	    { -logic_name => 'healthcheck',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
	      -parameters => {
			      'previous_db' => $self->o('previous_db'),
			      'ensembl_release' => $self->o('release'),
			      'prev_release' => $self->o('prev_release'),
			      'max_percent_diff' => $self->o('max_percent_diff'),
			     },
	      -wait_for => [ 'update_max_alignment_length_after_net' ],
	      -rc_name => '100Mb',
	    },
	    { -logic_name => 'pairaligner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
	      -parameters => {
			      'skip' => $self->o('skip_pairaligner_stats'),
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'create_pair_aligner_page' => $self->o('create_pair_aligner_page_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'ensembl_release' => $self->o('release'),
			      'reg_conf' => $self->o('reg_conf'),
			      'output_dir' => $self->o('output_dir'),
			     },
	      -wait_for =>  [ 'healthcheck' ],
	      -rc_name => '1Gb',
	    },
	   ];
}

1;
