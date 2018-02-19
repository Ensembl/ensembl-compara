=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Make sure that all default_options are set correctly, especially:
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options (eg if doing primate-primate alignments)
        bed_dir if running pairaligner_stats module

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --pipeline_name hsap_ggor_lastz_64 --password <your_password) --mlss_id 536 --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor/ --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --password <your_password> --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    The PipeConfig file for PairAligner pipeline that should automate most of the tasks. This is in need of further work, especially to deal with multiple pairs of species in the same database. Currently this is dealt with by using the same configuration file as before and the filename should be provided on the command line (--conf_file). 

    You may need to provide a registry configuration file if the core databases have not been added to staging (--reg_conf).

    A single pair of species can be run either by using a configuration file or by providing specific parameters on the command line and using the default values set in this file. On the command line, you must provide the LASTZ_NET mlss which should have been added to the master database (--mlss_id). The directory to which the nib files will be dumped can be specified using --dump_dir or the default location will be used. All the necessary directories are automatically created if they do not already exist. It may be necessary to change the pair_aligner_options default if, for example, doing primate-primate alignments. It is recommended that you provide a meaningful pipeline name (--pipeline_name). The username is automatically prefixed to this, ie --pipeline_name hsap_ggor_lastz_64 will create kb3_hsap_ggor_lastz_64 database. A basic healthcheck is run and output is written to the job_message table. To write to the pairwise configuration database, you must provide the correct config_url. Even if no config_url is given, the statistics are written to the job_message table.


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # executable locations:
        'populate_new_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",
        'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",
        'update_config_database_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/update_config_database.pl",
        'create_pair_aligner_page_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl",

            #Set for single pairwise mode
        'mlss_id' => '',

        #Collection name 
        'collection' => '',

	#Set to use pairwise configuration file
	'conf_file' => '',

	#Set to use registry configuration file
	'reg_conf' => '',

	#Reference species (if not using pairwise configuration file)
        'ref_species' => undef,

        # Dnafrags to load and align
        'only_cellular_component'   => undef,   # Do we load *all* the dnafrags or only the ones from a specific cellular-component ?
        'mix_cellular_components'   => 0,       # Do we try to allow the nuclear genome vs MT, etc ?

        #min length to dump
        'dump_min_nib_size'         => 11500000,
        'dump_min_chunk_size'       => 1000000,
        'dump_min_chunkset_size'    => 1000000,

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
        #NB: this is only used for the raw blocks and the chains. We always use the accurate version for the final nets
	'quick' => 1,

	#
	#Default chunking parameters
	#
     'default_chunks' => {
        'reference'   => { 
            'homo_sapiens' => {
                'chunk_size' => 30000000,
    			'overlap'    => 0,
    			'include_non_reference' => -1, #1  => include non_reference regions (eg human assembly patches)
    			                               #0  => do not include non_reference regions
    			                               #-1 => auto-detect (only include non_reference regions if the non-reference species is high-coverage 
    			                               #ie has chromosomes since these analyses are the only ones we keep up-to-date with the patches-pipeline)
                'masking_options' => '{default_soft_masking => 1}',
                #'masking_options_file' => $self->o('ensembl_cvs_root_dir') . "/ensembl-compara/scripts/pipeline/human36.spec",
            },
    	     #non human example
    		'default' => {
                'chunk_size'      => 10000000,
    				'overlap'         => 0,
    				'masking_options' => '{default_soft_masking => 1}'
            }
        },
    		'non_reference' => {
            'chunk_size'      => 10100000,
    			'group_set_size'  => 10100000,
    			'overlap'         => 100000,
    			'masking_options' => '{default_soft_masking => 1}'
        },
    	},
	    
        #
	#Default filter_duplicates
        #'window_size' => 1000000,
        'window_size' => 10000,
	'filter_duplicates_rc_name' => '1Gb',
	'filter_duplicates_himem_rc_name' => 'crowd_himem',

	#
	#Default pair_aligner
	#
   	'pair_aligner_method_link' => [1001, 'LASTZ_RAW'],
	'pair_aligner_logic_name' => 'LastZ',
	'pair_aligner_module' => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ',

    'pair_aligner_options' => {
        default => 'T=1 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', # ensembl genomes settings
        7742    => 'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac', # vertebrates - i.e. ensembl-specific
        9526    => 'T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=' . $self->o('ensembl_cvs_root_dir') . '/ensembl-compara/scripts/pipeline/primate.matrix --ambiguous=iupac', # primates
    },

        #
        #Default chain
        #
	'chain_input_method_link' => [1001, 'LASTZ_RAW'],
	'chain_output_method_link' => [1002, 'LASTZ_CHAIN'],

	 #linear_gap=>medium for more closely related species, 'loose' for more distant
	'linear_gap' => 'medium',

  	'chain_parameters' => {'max_gap'=>'50','linear_gap'=> $self->o('linear_gap'), 'faToNib' => $self->o('faToNib_exe'), 'lavToAxt'=> $self->o('lavToAxt_exe'), 'axtChain'=>$self->o('axtChain_exe'), 'max_blocks_for_chaining' => 100000},

	#
        #Default patch_alignments
        #
	'patch_alignments' => 0,  #set to 1 to align the patches of a species to many other species

        #
        #Default net 
        #
	'net_input_method_link' => [1002, 'LASTZ_CHAIN'],
        'net_output_method_link' => [16, 'LASTZ_NET'],
        'net_ref_species' => $self->o('ref_species'),  #default to ref_species
  	'net_parameters' => {'max_gap'=>'50', 'chainNet'=>$self->o('chainNet_exe')},
  	'bidirectional' => 0,

	#
	#Default healthcheck
	#
	'previous_db' => $self->o('livemirror_loc'),
	'prev_release' => 0,   # 0 is the default and it means "take current release number and subtract 1"    
	'max_percent_diff' => 20,
    'max_percent_diff_patches' => 99.99,
	'do_pairwise_gabs' => 1,
	'do_compare_to_previous_db' => 1,

        # Scratch disk space
        #'dump_dir' => ...,
        'bed_dir' => $self->o('dump_dir').'/bed_dir',
        'output_dir' => $self->o('dump_dir').'/feature_dumps',

        #
	#Default pairaligner config
	#
	'skip_pairaligner_stats' => 0, #skip this module if set to 1

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    print "pipeline_create_commands\n";

    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
            
        #Store CodingExon coverage statistics
        $self->db_cmd('CREATE TABLE IF NOT EXISTS statistics (
        method_link_species_set_id  int(10) unsigned NOT NULL,
        genome_db_id                int(10) unsigned NOT NULL,
        dnafrag_id                  bigint unsigned NOT NULL,
        matches                     INT(10) DEFAULT 0,
        mis_matches                 INT(10) DEFAULT 0,
        ref_insertions              INT(10) DEFAULT 0,
        non_ref_insertions          INT(10) DEFAULT 0,
        uncovered                   INT(10) DEFAULT 0,
        coding_exon_length          INT(10) DEFAULT 0
        ) COLLATE=latin1_swedish_ci ENGINE=InnoDB;'),

       'rm -rf '.$self->o('dump_dir').' '.$self->o('output_dir').' '.$self->o('bed_dir'), #Cleanup dump_dir directory
       'mkdir -p '.$self->o('dump_dir'), #Make dump_dir directory
       'mkdir -p '.$self->o('output_dir'), #Make output_dir directory
       'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
    ];
}


sub pipeline_analyses {
    my ($self) = @_;

    # Needed to "load" the parameters, i.e. to force them to be substituted
    # They can then be used in the healthcheck analysis
    $self->o('max_percent_diff');
    $self->o('max_percent_diff_patches');

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
	       -rc_name => '1Gb',
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
                  'pipeline_db'    => $self->pipeline_url(),
                  'only_cellular_component' => $self->o('only_cellular_component'),

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
                                  'collection' => $self->o('collection'),
				  'registry_dbs' => $self->o('curr_core_sources_locs'),
				  'core_dbs' => $self->o('curr_core_dbs_locs'),
				  'master_db' => $self->o('master_db'),
				  'do_pairwise_gabs' => $self->o('do_pairwise_gabs'), #healthcheck options
				  'do_compare_to_previous_db' => $self->o('do_compare_to_previous_db'), #healthcheck options
				  'bidirectional' => $self->o('bidirectional'),
  				  }, 
		-flow_into => {
			       1 => [ 'create_pair_aligner_jobs'],
			       2 => [ 'chunk_and_group_dna' ], 
			       3 => [ 'create_filter_duplicates_jobs' ],
			       4 => [ 'no_chunk_and_group_dna' ],
			       5 => [ 'create_alignment_chains_jobs' ],
			       6 => [ 'create_alignment_nets_jobs' ],
			       10 => [ 'create_filter_duplicates_net_jobs' ],
			       7 => [ 'pairaligner_stats' ],
			       8 => [ 'healthcheck' ],
			      },
	       -rc_name => '1Gb',
  	    },

 	    {  -logic_name => 'chunk_and_group_dna',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna',
 	       -parameters => {
                               'only_cellular_component' => $self->o('only_cellular_component'),
                               'mix_cellular_components' => $self->o('mix_cellular_components'),
			      },
 	       -flow_into => {
 	          2 => [ 'store_sequence' ],
 	       },
	       -rc_name => 'crowd',
 	    },
 	    {  -logic_name => 'store_sequence',
 	       -hive_capacity => 100,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence',
               -parameters => {
                   'dump_min_chunkset_size' => $self->o('dump_min_chunkset_size'),
                   'dump_min_chunk_size' => $self->o('dump_min_chunk_size'),
               },
	       -flow_into => {
 	          -1 => [ 'store_sequence_again' ],
 	       },
	       -rc_name => 'crowd',
  	    },
	    #If fail due to MEMLIMIT, probably due to memory leak, and rerunning with the default memory should be fine.
 	    {  -logic_name => 'store_sequence_again',
 	       -hive_capacity => 100,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence',
               -parameters => {
                   'dump_min_chunkset_size' => $self->o('dump_min_chunkset_size'),
                   'dump_min_chunk_size' => $self->o('dump_min_chunk_size'),
               },
	       -can_be_empty  => 1,
	       -rc_name => 'crowd',
  	    },
 	    {  -logic_name => 'create_pair_aligner_jobs',  #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs',
 	       -parameters => { 
                               'mix_cellular_components' => $self->o('mix_cellular_components'),
                              },
	       -hive_capacity => 10,
 	       -wait_for => [ 'store_sequence', 'store_sequence_again', 'chunk_and_group_dna'  ],
	       -flow_into => {
			       1 => [ 'check_no_partial_gabs' ],
			       2 => [ $self->o('pair_aligner_logic_name')  ],
			   },
	       -rc_name => 'long',
 	    },
 	    {  -logic_name => $self->o('pair_aligner_logic_name'),
 	       -module     => $self->o('pair_aligner_module'),
 	       -analysis_capacity => $self->o('pair_aligner_analysis_capacity'),
 	       -batch_size => $self->o('pair_aligner_batch_size'),
	       -parameters => { 
			       'pair_aligner_exe' => $self->o('pair_aligner_exe'),
			      },
           -wait_for  => [ 'create_pair_aligner_jobs'  ],
	       -flow_into => {
			      -1 => [ $self->o('pair_aligner_logic_name') . '_himem1' ],  # MEMLIMIT
			     },
	       -rc_name => 'crowd',
	    },
	    {  -logic_name => $self->o('pair_aligner_logic_name') . "_himem1",
 	       -module     => $self->o('pair_aligner_module'),
 	       -analysis_capacity => $self->o('pair_aligner_analysis_capacity'),
	       -parameters => { 
			       'pair_aligner_exe' => $self->o('pair_aligner_exe'),
			      },
           -wait_for   => [ 'create_pair_aligner_jobs'  ],
 	       -batch_size => $self->o('pair_aligner_batch_size'),
	       -can_be_empty  => 1,
	       -rc_name => 'crowd_himem',
	    },
            {   -logic_name => 'check_no_partial_gabs',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SqlHealthChecks',
                -parameters => {
                    'mode'          => 'gab_inconsistencies',
                },
 	       -wait_for =>  [ $self->o('pair_aligner_logic_name'), $self->o('pair_aligner_logic_name') . "_himem1" ],
	       -flow_into => {
			      1 => [ 'update_max_alignment_length_before_FD' ],
			     },
	    },
 	    {  -logic_name => 'update_max_alignment_length_before_FD',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -flow_into => {
			      1 => [ 'update_max_alignment_length_after_FD' ],
			     },
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'create_filter_duplicates_jobs', #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs',
 	       -parameters => { },
 	       -wait_for =>  [ 'update_max_alignment_length_before_FD' ],
	        -flow_into => {
			       2 => { 'filter_duplicates' => INPUT_PLUS() },
			     },
	       -rc_name => '1Gb',
 	    },
 	     {  -logic_name   => 'filter_duplicates',
 	       -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates',
 	       -parameters    => { 
				  'window_size' => $self->o('window_size') 
				 },
	       -hive_capacity => $self->o('filter_duplicates_hive_capacity'),
	       -batch_size    => $self->o('filter_duplicates_batch_size'),
	       -can_be_empty  => 1,
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
	       -hive_capacity => $self->o('filter_duplicates_hive_capacity'),
	       -batch_size    => $self->o('filter_duplicates_batch_size'),
	       -can_be_empty  => 1,
	       -rc_name => $self->o('filter_duplicates_himem_rc_name'),
 	    },
 	    {  -logic_name => 'update_max_alignment_length_after_FD',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => {
			       'quick' => $self->o('quick'),
			      },
               -wait_for =>  [ 'create_filter_duplicates_jobs', 'filter_duplicates', 'filter_duplicates_himem' ],
	       -rc_name => '1Gb',
 	    },
#
#Second half of the pipeline
#

 	    {  -logic_name => 'no_chunk_and_group_dna',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna',
 	       -parameters => {
                               'only_cellular_component' => $self->o('only_cellular_component'),
                               'mix_cellular_components' => $self->o('mix_cellular_components'),
			      },
	       -flow_into => {
			      2 => [ 'dump_large_nib_for_chains' ],
			     },
	       -wait_for  => ['update_max_alignment_length_after_FD' ],
	       -rc_name => 'crowd',
 	    },
 	    {  -logic_name => 'dump_large_nib_for_chains',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection',
 	       -parameters => {
			       'faToNib_exe' => $self->o('faToNib_exe'),
			       'dump_min_nib_size' => $self->o('dump_min_nib_size'),
                               'overwrite'=>1,
			      },
	       -hive_capacity => 10,
	       -flow_into => {
			      -1 => [ 'dump_large_nib_for_chains_himem' ],  # MEMLIMIT
			     },
	       -rc_name => 'crowd',
 	    },
	    {  -logic_name => 'dump_large_nib_for_chains_himem',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection',
 	       -parameters => {
			       'faToNib_exe' => $self->o('faToNib_exe'),
			       'dump_min_nib_size' => $self->o('dump_min_nib_size'),
                               'overwrite'=>1,
			      },
	       -hive_capacity => 10,
	       -can_be_empty  => 1,
	       -rc_name => 'crowd_himem',
 	    },
 	    {  -logic_name => 'create_alignment_chains_jobs',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentChainsJobs',
		-parameters => { }, 
		-flow_into => {
#			      1 => [ 'update_max_alignment_length_after_chain' ],
			      1 => [ 'remove_inconsistencies_after_chain' ],
			      2 => [ 'alignment_chains' ],
			     },
               -wait_for => [ 'no_chunk_and_group_dna', 'dump_large_nib_for_chains', 'dump_large_nib_for_chains_himem' ],
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'alignment_chains',
 	       -hive_capacity => $self->o('chain_hive_capacity'),
 	       -batch_size => $self->o('chain_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
 	       -parameters => $self->o('chain_parameters'),
           -max_retry_count => 10,
	       -flow_into => {
			      -1 => [ 'alignment_chains_himem' ],  # MEMLIMIT
			     },
               -wait_for   => [ 'create_alignment_chains_jobs' ],
	       -rc_name => 'crowd',
 	    },
	    {  -logic_name => 'alignment_chains_himem',
	       -hive_capacity => $self->o('chain_hive_capacity'),
 	       -batch_size => 1,
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
 	       -parameters => $self->o('chain_parameters'),
	       -can_be_empty  => 1,
           -max_retry_count => 10,
	       -rc_name => 'crowd_himem',
           -wait_for => ['alignment_chains'],
	       -can_be_empty  => 1,
 	    },
	    {
	     -logic_name => 'remove_inconsistencies_after_chain',
	     -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	     -flow_into => {
			      1 => [ 'update_max_alignment_length_after_chain' ],
			   },
	     -wait_for =>  [ 'alignment_chains', 'alignment_chains_himem' ],
	     -rc_name => '1Gb',
	    },
	    {  -logic_name => 'update_max_alignment_length_after_chain',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'create_alignment_nets_jobs',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentNetsJobs',
 	       -parameters => { },
		-flow_into => {
			       1 => [ 'remove_inconsistencies_after_net' ],
			       2 => [ 'alignment_nets' ],
			      },
 	       -wait_for => [ 'update_max_alignment_length_after_chain', 'remove_inconsistencies_after_chain' ],
	       -rc_name => '1Gb',
 	    },
 	    {  -logic_name => 'alignment_nets',
 	       -hive_capacity => $self->o('net_hive_capacity'),
 	       -batch_size => $self->o('net_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
 	       -parameters => $self->o('net_parameters'),
	       -flow_into => {
			      -1 => [ 'alignment_nets_himem' ],  # MEMLIMIT
			     },
	       -rc_name => '1Gb',
 	    },
	    {  -logic_name => 'alignment_nets_himem',
 	       -hive_capacity => $self->o('net_hive_capacity'),
 	       -batch_size => $self->o('net_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
 	       -parameters => $self->o('net_parameters'),
               -can_be_empty => 1,
	       -rc_name => 'crowd',
 	    },
 	    {
	       -logic_name => 'remove_inconsistencies_after_net',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	       -flow_into => {
			       1 => [ 'update_max_alignment_length_after_net' ],
			   },
 	       -wait_for =>  [ 'alignment_nets', 'alignment_nets_himem', 'create_alignment_nets_jobs' ],    # Needed because of bi-directional netting: 2 jobs in create_alignment_nets_jobs can result in 1 job here
	       -rc_name => '1Gb',
	    },
 	    {  -logic_name => 'create_filter_duplicates_net_jobs', #factory
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs',
               -parameters => { },
               -wait_for =>  [ 'remove_inconsistencies_after_net' ],
               -flow_into => {
                              2 => { 'filter_duplicates_net' => INPUT_PLUS() },
                            },
               -can_be_empty  => 1,
               -rc_name => 'crowd',
           },
           {  -logic_name   => 'filter_duplicates_net',
              -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates',
              -parameters    => { 
                                 'window_size' => $self->o('window_size'),
                                 'filter_duplicates_net' => 1,
                                },
              -hive_capacity => $self->o('filter_duplicates_hive_capacity'),
              -batch_size    => $self->o('filter_duplicates_batch_size'),
              -flow_into => {
                              -1 => [ 'filter_duplicates_net_himem' ], # MEMLIMIT
                            },
              -can_be_empty  => 1,
              -rc_name => $self->o('filter_duplicates_rc_name'),
           },
           {  -logic_name   => 'filter_duplicates_net_himem',
              -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates',
              -parameters    => { 
                                 'window_size' => $self->o('window_size'),
                                 'filter_duplicates_net' => 1,
                                },
              -hive_capacity => $self->o('filter_duplicates_hive_capacity'),
              -batch_size    => $self->o('filter_duplicates_batch_size'),
              -can_be_empty  => 1,
              -rc_name => $self->o('filter_duplicates_himem_rc_name'),
           },
 	   {  -logic_name => 'update_max_alignment_length_after_net',
 	      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	      -rc_name => '1Gb',
	      -wait_for =>  [ 'create_filter_duplicates_net_jobs', 'filter_duplicates_net', 'filter_duplicates_net_himem' ],
              -flow_into => [ 'set_internal_ids_collection' ],
 	    },
          {  -logic_name => 'set_internal_ids_collection',
              -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection',
              -parameters => {
                  'skip' => $self->o('patch_alignments'),
              },
              -analysis_capacity => 1,
              -rc_name => '100Mb',
          },
	    { -logic_name => 'healthcheck',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
	      -parameters => {
			      'previous_db' => $self->o('previous_db'),
			      'ensembl_release' => $self->o('ensembl_release'),
			      'prev_release' => $self->o('prev_release'),
			      'max_percent_diff' => $self->o('patch_alignments') ? $self->o('max_percent_diff_patches') : $self->o('max_percent_diff'),
			     },
	      -wait_for => [ 'set_internal_ids_collection' ],
	      -rc_name => '1Gb',
	    },
	    { -logic_name => 'pairaligner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
	      -parameters => {
			      # 'skip' => $self->o('skip_pairaligner_stats'),
            'skip' => '#expr( #skip_pairaligner_stats# || #patch_alignments# )expr#',
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'create_pair_aligner_page' => $self->o('create_pair_aligner_page_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'ensembl_release' => $self->o('ensembl_release'),
			      'reg_conf' => $self->o('reg_conf'),
			      'output_dir' => $self->o('output_dir'),
			     },
	      -wait_for =>  [ 'healthcheck' ],
              -flow_into => {
                  'A->1' => [ 'coding_exon_stats_summary' ],
                  '2->A' => [ 'coding_exon_stats' ],
			     },
	      -rc_name => '1Gb',
	    },
            {   -logic_name => 'coding_exon_stats',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats',
                -hive_capacity => 5,
                -rc_name => '1Gb',
#                -rc_name => '1Gb_core',
            },
            {   -logic_name => 'coding_exon_stats_summary',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary',
                -rc_name => '1Gb',
            },
	   ];
}

1;
