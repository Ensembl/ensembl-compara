=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

 Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf

=head1 SYNOPSIS

    #0. This script is simply a pared-down version of Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf
        -- all the alignment steps have been removed but otherwise it is the same.

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. You may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. Make sure that all default_options are set correctly, especially:
        release
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        bed_dir

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf --dbname hsap_ggor_lastz_64 --password <your_password) --mlss_id 536 --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor_nib_files/ --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --password <your_password> --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    You will probably need to provide a registry configuration file pointing to pore and compara databases (--reg_conf).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PairAlignerStats_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        #'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/src/ensembl_main/', 
        'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'}, 

	'release'               => '77',
        'release_suffix'        => '',    # an empty string by default, a letter otherwise
	#'dbname'               => '', #Define on the command line. Compara database name eg hsap_ggor_lastz_64

         # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
        'pipeline_name'         => 'pairalign_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

        'host'        => 'mysql-eg-hive.ebi.ac.uk',                        #separate parameter to use the resources aswell
        'pipeline_db' => {                                  # connection parameters
            -host   => $self->o('host'),
            -port   => 4411,
            -user   => 'ensrw',
            -pass   => $self->o('password'), 
            -dbname => $ENV{USER}.'_'.$self->o('dbname'),
            -driver => 'mysql',
        },

	    'master_db' => 'mysql://ensro@mysql-eg-staging-2.ebi.ac.uk:4275/ensembl_compara_metazoa_24_77',

	# 'staging_loc1' => {
        #     -host   => 'ens-staging1',
        #     -port   => 3306,
        #     -user   => 'ensro',
        #     -pass   => '',
        # },

	    'staging_loc2' => {
			       -host   => 'mysql-eg-staging-2.ebi.ac.uk',
			       -port   => 4275,
			       -user   => 'ensro',
			       -pass   => '',
			       -driver => 'mysql',
			       -db_version => 77,
			      },

	    'main_core_dbs' => [{
			       -host   => 'mysql-eg-staging-2.ebi.ac.uk',
			       -port   => 4275,
			       -user   => 'ensro',
			       -pass   => '',
			       -driver => 'mysql',
			       -db_version => 77,
			      },],

	  'livemirror_loc' => {
			       -host   => 'mysql-eg-mirror.ebi.ac.uk',
			       -port   => 4205,
			       -user   => 'ensro',
			       -pass   => '',
			       -db_version => 76,
			      },
	  'pipeline_db' => {
	  		    -host => $self->o('hive_db_host'),
	  		    -port => $self->o('hive_db_port'),
	  		    -user => $self->o('hive_db_user'),
	  		    -pass => $self->o('hive_db_password'),
	  		    -dbname => $self->o('pipeline_name'),
			    -driver => $self->o('hive_db_driver'),
	  		   },

	'curr_core_sources_locs'    => [ $self->o('staging_loc2'), ],
	#'curr_core_sources_locs'    => [ $self->o('livemirror_loc') ],
	'curr_core_dbs_locs'        => '', #if defining core dbs with config file. Define in Lastz_conf.pm or TBlat_conf.pm
	    'core_db_urls' => {}, #'mysql://ensro@mysql-eg-staging-2.ebi.ac.uk:4275/77',
	# executable locations:
	'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",
	'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
	'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",
	'update_config_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/update_config_database.pl",
	'create_pair_aligner_page_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl",

	    'faToNib_exe' => $self->o('exe_dir').'/faToNib',
	    'lavToAxt_exe' => $self->o('exe_dir').'/lavToAxt',
	    'axtChain_exe' => $self->o('exe_dir').'/axtChain',
	    'chainNet_exe' => $self->o('exe_dir').'/chainNet',

	#Set for single pairwise mode
	'mlss_id' => '',

        #Collection name 
        'collection' => '',

	#Set to use pairwise configuration file
#	'conf_file' => '/nfs/production/panda/ensemblgenomes/production/bwalts/compare_pairaligner_stats_22_75/plants_23_76/coding-region-stats/Bio/EnsEMBL/Compara/PipeConfig/PairAlignerStats_conf.pm',

	    'conf_file' => '',

	#Set to use registry configuration file
	'reg_conf' => '',

	#Reference species (if not using pairwise configuration file)
        'ref_species' => undef,

	#directory to dump nib files

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
	'bed_dir' => '/nfs/production/panda/ensemblgenomes/production/'.$ENV{USER}.'/pairaligner_stats/coding-region-stats',
	'output_dir' => '/nfs/production/panda/ensemblgenomes/production/'.$ENV{USER}.'/pairaligner_stats/coding-region-stats',
            
        #
        #Resource requirements
        #
        'memory_suffix' => "",                    #temporary fix to define the memory requirements in resource_classes
        'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
        'aligner_capacity' => 2000,

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
            
        #Store CodingExon coverage statistics
        'mysql ' . $self->dbconn_2_mysql('pipeline_db', 1) . ' -e "CREATE TABLE IF NOT EXISTS statistics (
        method_link_species_set_id  int(10) unsigned NOT NULL,
        species_name                varchar(40) NOT NULL DEFAULT \'\',
        seq_region                  varchar(40) NOT NULL DEFAULT \'\',
        matches                     INT(10) DEFAULT 0,
        mis_matches                 INT(10) DEFAULT 0,
        ref_insertions              INT(10) DEFAULT 0,
        non_ref_insertions          INT(10) DEFAULT 0,
        uncovered                   INT(10) DEFAULT 0,
        coding_exon_length          INT(10) DEFAULT 0
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;"',

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
	    'additional_core_db_urls' => $self->o('core_db_urls'),
	    'main_core_dbs' => $self->o('main_core_dbs'),
    };
}

sub resource_classes {
    my ($self) = @_;

    my $host = $self->o('pipeline_db')->{host};
    return {
	    %{$self->SUPER::resource_classes}, # inherit 'default' from the parent class
	    '100Mb' => { 'LSF' => '-q production-rh6 -M100 -R"rusage[mem=100]"' },
	    '1Gb'   => { 'LSF' => '-q production-rh6 -M1000 -R"rusage[mem=1000]"' },
	    '1.8Gb' => { 'LSF' => '-q production-rh6 -M1800 -R"rusage[mem=1800]"' },
	    '3.6Gb' => { 'LSF' => '-q production-rh6 -M3600 -R"rusage[mem=3600]"' },
	   };
}

sub pipeline_analyses {
    my ($self) = @_;

    return [
	    # ---------------------------------------------[Turn all tables except 'genome_db' to InnoDB]---------------------------------------------
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
                -input_ids => [{}],
		-flow_into      => {
				    1 => ['populate_new_database'],
				   },
	       -rc_name => '100Mb',
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'reg_conf'        => $self->o('reg_conf'),
				  'mlss_id'        => $self->o('mlss_id'),
                                  'collection'     => $self->o('collection'),
                                  'master_db'      => $self->o('master_db'),
                                  'pipeline_db'    => $self->dbconn_2_url('pipeline_db'),
                                  'MT_only'        => $self->o('MT_only'),
				  'old_compara_db' => $self->o('old_compara_db'),
				 },
	       -flow_into => {
			      1 => [ 'set_genome_db_locator_factory' ],
			     },
	       -rc_name => '3.6Gb',
	    },

	    {
	     -logic_name => 'set_genome_db_locator_factory',
	     -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
	     -parameters => {
	    		     'inputquery' => 'SELECT name AS species_loc_name FROM genome_db WHERE assembly_default',
	    		    },
	     -flow_into => { 1 => ['pairaligner_stats'],
			     2 => ['update_genome_db_locator'],
	    		   },
	    },

	    {
	     -logic_name => 'update_genome_db_locator',
	     -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator',
	     -meadow_type    => 'LOCAL',
	     # -flow_into => { 1 => ['pairaligner_stats'],
	     # 		   },
	    },


	    { -logic_name => 'pairaligner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
	      -wait_for => ['update_genome_db_locator'],
	      -parameters => {
			      'skip' => $self->o('skip_pairaligner_stats'),
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'create_pair_aligner_page' => $self->o('create_pair_aligner_page_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'mlss_id'        => $self->o('mlss_id'),
			      'ensembl_release' => $self->o('release'),
			      'reg_conf' => $self->o('reg_conf'),
			      'output_dir' => $self->o('output_dir'),
			     },

              -flow_into => {
                              1 => [ 'coding_exon_stats_summary' ],
			      2 => [ 'coding_exon_stats' ],
			     },
	      -rc_name => '1Gb',
	    },
            {   -logic_name => 'coding_exon_stats',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats',
                -hive_capacity => 10,
                -rc_name => '1Gb',
            },
            {   -logic_name => 'coding_exon_stats_summary',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary',
		-parameters => {
				'mlss_id' => $self->o('mlss_id'),
				},
                -rc_name => '1Gb',
                -wait_for =>  [ 'coding_exon_stats' ],
            },
	   ];
}

1;
