=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. Make sure that all default_options are set correctly, especially:
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        default_chunks
        pair_aligner_options (eg if doing primate-primate alignments)
        bed_dir if running pairaligner_stats module

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf -host mysql-ens-compara-prod-X -port XXXX \
            --pipeline_name hsap_ggor_lastz_64 --mlss_id 536 --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/ \
            --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor/ \
            --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf -host mysql-ens-compara-prod-X -port XXXX \
            --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

The PipeConfig file for PairAligner pipeline that should automate most of the tasks. This is in need of further work, especially to deal with multiple pairs of species in the same database. Currently this is dealt with by using the same configuration file as before and the filename should be provided on the command line (--conf_file). 

You may need to provide a registry configuration file if the core databases have not been added to staging (--reg_conf).

A single pair of species can be run either by using a configuration file or by providing specific parameters on the command line and using the default values set in this file. On the command line, you must provide the LASTZ_NET mlss which should have been added to the master database (--mlss_id). The directory to which the nib files will be dumped can be specified using --dump_dir or the default location will be used. All the necessary directories are automatically created if they do not already exist. It may be necessary to change the pair_aligner_options default if, for example, doing primate-primate alignments. It is recommended that you provide a meaningful pipeline name (--pipeline_name). The username is automatically prefixed to this, ie --pipeline_name hsap_ggor_lastz_64 will create kb3_hsap_ggor_lastz_64 database. A basic healthcheck is run and output is written to the job_message table. To write to the pairwise configuration database, you must provide the correct config_url. Even if no config_url is given, the statistics are written to the job_message table.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

            #Set for single pairwise mode
        'mlss_id' => '',
        'mlss_id_list' => undef,

        #Collection name 
        'collection' => '',

	#Set to use pairwise configuration file
	'conf_file' => '',

        #The registry file "reg_conf" is automatically set up in the parent class
        'master_db' => 'compara_master',

        # Work directory
        'dump_dir' => $self->o('pipeline_dir'),

	#Reference species (if not using pairwise configuration file)
        'ref_species' => undef,
        'non_ref_species' => undef,

        # Dnafrags to load and align
        'only_cellular_component'   => undef,   # Do we load *all* the dnafrags or only the ones from a specific cellular-component ?
        'mix_cellular_components'   => 0,       # Do we try to allow the nuclear genome vs MT, etc ?

        #min length to dump
        'dump_min_nib_size'         => 11500000,

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
        #NB: this is only used for the raw blocks and the chains. We always use the accurate version for the final nets
	'quick' => 1,


        # Default chunking parameters
        'default_chunks' => {
            'reference' => {
                'homo_sapiens' => {
                    'chunk_size'            => 30000000,
                    'overlap'               => 0,
                    # include_non_reference parameter options:
                    #    1 => include non_reference regions (e.g. human assembly patches)
                    #    0 => do not include non_reference regions
                    #   -1 => auto-detect (only include non_reference regions if the non-reference species is
                    #         high-coverage, i.e. has chromosomes, since these analyses are the only ones we keep
                    #         up-to-date with the patches-pipeline)
                    'include_non_reference' => -1,
                },
                # non human example
                'default' => {
                    'chunk_size'     => 10000000,
                    'group_set_size' => 10100000,
                    'overlap'        => 0,
                }
            },
            'non_reference' => {
                'chunk_size'     => 10100000,
                'group_set_size' => 10100000,
                'overlap'        => 100000,
            },
            'masking' => 'soft',
        },

	#Default filter_duplicates
        #'window_size' => 1000000,
        'window_size' => 10000,
	'filter_duplicates_rc_name' => '1Gb_job',
    'filter_duplicates_himem_rc_name' => '8Gb_job',

	 #linear_gap=>medium for more closely related species, 'loose' for more distant
	'linear_gap' => 'medium',

        'chain_parameters' => {'max_gap'=>'50','linear_gap'=> $self->o('linear_gap'), 'faToNib_exe' => $self->o('faToNib_exe'), 'lavToAxt_exe'=> $self->o('lavToAxt_exe'), 'axtChain_exe'=>$self->o('axtChain_exe'), 'max_blocks_for_chaining' => 100000},

        #Default patch_alignments
	'patch_alignments' => 0,  #set to 1 to align the patches of a species to many other species

        #Default net 
        'net_ref_species' => $self->o('ref_species'),  #default to ref_species
        'net_parameters' => {'max_gap'=>'50', 'chainNet_exe'=>$self->o('chainNet_exe')},
  	'bidirectional' => 0,

	#Default healthcheck
    'previous_db' => 'compara_prev',
	'prev_release' => 0,   # 0 is the default and it means "take current release number and subtract 1"    
	'max_percent_diff' => 20,
    'max_percent_diff_patches' => 99.99,
	'do_pairwise_gabs' => 1,
	'do_compare_to_previous_db' => 1,

        # Scratch disk space
        #'dump_dir' => ...,
        'bed_dir' => $self->o('dump_dir').'/bed_dir',
        'output_dir' => $self->o('dump_dir').'/feature_dumps',

	#Default pairaligner config
	'skip_pairaligner_stats' => 0, #skip this module if set to 1

    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        'skip_pairaligner_stats'    => $self->o('skip_pairaligner_stats'),
        'patch_alignments'          => $self->o('patch_alignments'),
        'genome_dumps_dir'          => $self->o('genome_dumps_dir'),
    };
}


sub pipeline_create_commands {
    my ($self) = @_;

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

       $self->pipeline_create_commands_rm_mkdir(['dump_dir', 'output_dir', 'bed_dir']),
    ];
}


sub core_pipeline_analyses {
    my ($self) = @_;

    # Needed to "load" the parameters, i.e. to force them to be substituted
    # They can then be used in the healthcheck analysis
    $self->o('max_percent_diff');
    $self->o('max_percent_diff_patches');

    return [
	    {   -logic_name    => 'get_species_list',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf',
		-parameters    => { 
				  #'compara_url' => $self->dbconn_2_url('master_db'),
				   'master_db' => $self->o('master_db'),
				  'conf_file' => $self->o('conf_file'),
				  'get_species_list' => 1,
				  }, 
                -input_ids => [{}],
		-flow_into      => {
				    1 => ['populate_new_database'],
				   },
	       -rc_name => '1Gb_job',
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_exe'),
				  'reg_conf'        => $self->o('reg_conf'),
				  'mlss_id'        => $self->o('mlss_id'),
				  'mlss_id_list'   => $self->o('mlss_id_list'),
                  'collection'     => $self->o('collection'),
                  'master_db'      => $self->o('master_db'),
                  'cellular_component' => $self->o('only_cellular_component'),
				 },
	       -flow_into => {
			      1 => [ 'parse_pair_aligner_conf' ],
			     },
	       -rc_name => '1Gb_job',
	    },

	    #Need reg_conf, conf_file or registry_dbs to define the location of the core dbs
	    # The work of load_genomedb is currently done by parse_pair_aligner_conf but should be moved to LoadOneGenomeDB really
  	    {   -logic_name    => 'parse_pair_aligner_conf',
  		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf',
  		-parameters    => { 
  				  'conf_file' => $self->o('conf_file'),
				  'ref_species' => $self->o('ref_species'),
				  'non_ref_species' => $self->o('non_ref_species'),
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
				  'mlss_id_list' => $self->o('mlss_id_list'),
                                  'collection' => $self->o('collection'),
				  'master_db' => $self->o('master_db'),
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
			       9 => [ 'detect_component_mlsss' ],
			      },
	       -rc_name => '1Gb_job',
  	    },

 	    {  -logic_name => 'chunk_and_group_dna',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ChunkAndGroupDna',
 	       -parameters => {
                               'only_cellular_component' => $self->o('only_cellular_component'),
                               'mix_cellular_components' => $self->o('mix_cellular_components'),
			      },
	       -rc_name => '2Gb_job',
 	    },

        {   -logic_name    => 'create_pair_aligner_jobs',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs',
            -parameters    => {
                'mix_cellular_components' => $self->o('mix_cellular_components'),
            },
            -flow_into     => {
                '2->A' => [ $self->o('pair_aligner_logic_name')  ],
                'A->1' => [ 'check_no_partial_gabs' ],
            },
            -wait_for      => [ 'chunk_and_group_dna' ],
            -hive_capacity => 10,
            -rc_name       => '1Gb_job',
        },

        {   -logic_name        => $self->o('pair_aligner_logic_name'),
            -module            => $self->o('pair_aligner_module'),
            -parameters        => {
                'pair_aligner_exe' => $self->o('pair_aligner_exe'),
            },
            -flow_into         => {
                -1 => [ $self->o('pair_aligner_logic_name') . '_himem' ],  # MEMLIMIT
            },
            -analysis_capacity => $self->o('pair_aligner_analysis_capacity'),
            -batch_size        => $self->o('pair_aligner_batch_size'),
            -rc_name           => '2Gb_job',
        },

        {   -logic_name        => $self->o('pair_aligner_logic_name') . '_himem',
            -module            => $self->o('pair_aligner_module'),
            -parameters        => {
                'pair_aligner_exe' => $self->o('pair_aligner_exe'),
            },
            -analysis_capacity => $self->o('pair_aligner_analysis_capacity'),
            -batch_size        => $self->o('pair_aligner_batch_size'),
            -rc_name           => '8Gb_job',
        },

        {   -logic_name => 'check_no_partial_gabs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SqlHealthChecks',
            -parameters => {
                'mode' => 'gab_inconsistencies',
            },
            -flow_into  => {
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
	       -rc_name => '1Gb_job',
 	    },
 	    {  -logic_name => 'create_filter_duplicates_jobs', #factory
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs',
 	       -wait_for =>  [ 'update_max_alignment_length_before_FD', 'check_no_partial_gabs', 'create_pair_aligner_jobs', $self->o('pair_aligner_logic_name') ],
	        -flow_into => {
			       2 => { 'filter_duplicates' => INPUT_PLUS() },
			     },
	       -rc_name => '1Gb_job',
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
	       -rc_name => '1Gb_job',
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
	       -wait_for  => ['update_max_alignment_length_after_FD' ],
	       -rc_name => '2Gb_job',
 	    },

        {   -logic_name => 'create_alignment_chains_jobs',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentChainsJobs',
            -flow_into  => {
                '2->A' => [ 'alignment_chains' ],
                'A->1' => [ 'remove_inconsistencies_after_chain' ],
            },
            -wait_for   => [ 'no_chunk_and_group_dna' ],
            -rc_name    => '2Gb_job',
        },

        {   -logic_name      => 'alignment_chains',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
            -parameters      => $self->o('chain_parameters'),
            -flow_into       => {
                -1 => [ 'alignment_chains_himem' ],  # MEMLIMIT
            },
            -batch_size      => $self->o('chain_batch_size'),
            -hive_capacity   => $self->o('chain_hive_capacity'),
            -rc_name         => '4Gb_job',
            -max_retry_count => 10,
        },

        {   -logic_name      => 'alignment_chains_himem',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
            -parameters      => $self->o('chain_parameters'),
            -flow_into       => {
                -1 => [ 'alignment_chains_hugemem' ],  # MEMLIMIT
            },
            -batch_size      => 1,
            -hive_capacity   => $self->o('chain_hive_capacity'),
            -rc_name         => '8Gb_job',
            -max_retry_count => 10,
        },

        {   -logic_name      => 'alignment_chains_hugemem',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains',
            -parameters      => $self->o('chain_parameters'),
            -batch_size      => 1,
            -hive_capacity   => $self->o('chain_hive_capacity'),
            -rc_name         => '16Gb_job',
            -max_retry_count => 10,
        },

        {   -logic_name => 'remove_inconsistencies_after_chain',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
            -flow_into  => {
                1 => [ 'update_max_alignment_length_after_chain' ],
			},
            -rc_name    => '1Gb_job',
        },

	    {  -logic_name => 'update_max_alignment_length_after_chain',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
 	       -parameters => { 
			       'quick' => $self->o('quick'),
			      },
	       -rc_name => '1Gb_job',
 	    },
 	    {  -logic_name => 'create_alignment_nets_jobs',
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentNetsJobs',
 	       -parameters => { },
		-flow_into => {
			       1 => [ 'remove_inconsistencies_after_net' ],
			       2 => [ 'alignment_nets' ],
			      },
            -wait_for => [ 'update_max_alignment_length_after_chain', 'create_alignment_chains_jobs', 'remove_inconsistencies_after_chain', 'alignment_chains' ],
	       -rc_name => '1Gb_job',
 	    },
 	    {  -logic_name => 'alignment_nets',
 	       -hive_capacity => $self->o('net_hive_capacity'),
 	       -batch_size => $self->o('net_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
 	       -parameters => $self->o('net_parameters'),
	       -flow_into => {
			      -1 => [ 'alignment_nets_himem' ],  # MEMLIMIT
			     },
	       -rc_name => '1Gb_job',
 	    },
	    {  -logic_name => 'alignment_nets_himem',
 	       -hive_capacity => $self->o('net_hive_capacity'),
 	       -batch_size => $self->o('net_batch_size'),
 	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
 	       -parameters => $self->o('net_parameters'),
               -can_be_empty => 1,
               -flow_into => {
                   -1 => [ 'alignment_nets_hugemem' ],  # MEMLIMIT
               },
	       -rc_name => '4Gb_job',
 	    },
            {   -logic_name     => 'alignment_nets_hugemem',
                -hive_capacity  => $self->o('net_hive_capacity'),
                -batch_size     => $self->o('net_batch_size'),
                -module         => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets',
                -parameters     => $self->o('net_parameters'),
                -can_be_empty   => 1,
                -rc_name        => '8Gb_job',
            },
 	    {
	       -logic_name => 'remove_inconsistencies_after_net',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
	       -flow_into => {
			       1 => [ 'remove_inconsistencies_after_net_fd' ],
			   },
 	       -wait_for =>  [ 'alignment_nets', 'alignment_nets_himem', 'alignment_nets_hugemem', 'create_alignment_nets_jobs' ],    # Needed because of bi-directional netting: 2 jobs in create_alignment_nets_jobs can result in 1 job here
	       -rc_name => '1Gb_job',
	    },
 	    {  -logic_name => 'create_filter_duplicates_net_jobs', #factory
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs',
               -parameters => { },
               -wait_for =>  [ 'remove_inconsistencies_after_net' ],
               -flow_into => {
                              2 => { 'filter_duplicates_net' => INPUT_PLUS() },
                            },
               -can_be_empty  => 1,
               -rc_name => '2Gb_job',
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

           {  -logic_name    => 'remove_inconsistencies_after_net_fd',
              -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::RemoveAlignmentDataInconsistencies',
              -flow_into     => {
                   1 => [ 'update_max_alignment_length_after_net' ],
               },
              -wait_for      => [ 'create_filter_duplicates_net_jobs', 'filter_duplicates_net', 'filter_duplicates_net_himem' ],
           },

 	   {  -logic_name => 'update_max_alignment_length_after_net',
 	      -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	      -rc_name => '1Gb_job',
 	    },

        {   -logic_name => 'detect_component_mlsss',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DetectComponentMLSSs',
            -parameters => {
                'do_pairwise_gabs'          => $self->o('do_pairwise_gabs'),
                'do_compare_to_previous_db' => $self->o('do_compare_to_previous_db'),
            },
            -wait_for   => [ 'update_max_alignment_length_after_net' ],
            -flow_into  => {
                '3->A' => [ 'lift_to_principal' ],
                'A->2' => [ 'run_healthchecks' ],
            },
        },

        {   -logic_name      => 'lift_to_principal',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LiftComponentAlignments',
            -max_retry_count => 1,
        },

        {   -logic_name => 'run_healthchecks',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -flow_into  => {
                '2->A' => [ 'healthcheck' ],
                'A->1' => [ 'pairaligner_stats' ],
            },
        },

        {   -logic_name => 'healthcheck',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
            -parameters => {
                'previous_db'      => $self->o('previous_db'),
                'ensembl_release'  => $self->o('ensembl_release'),
                'prev_release'     => $self->o('prev_release'),
                'max_percent_diff' => $self->o('patch_alignments') ? $self->o('max_percent_diff_patches') : $self->o('max_percent_diff'),
            },
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'pairaligner_stats',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats',
            -parameters => {
                'skip'                     => '#expr( #skip_pairaligner_stats# || #patch_alignments# )expr#',
                'dump_features'            => $self->o('dump_features_exe'),
                'compare_beds'             => $self->o('compare_beds_exe'),
                'create_pair_aligner_page' => $self->o('create_pair_aligner_page_exe'),
                'bed_dir'                  => $self->o('bed_dir'),
                'output_dir'               => $self->o('output_dir'),
            },
            -flow_into  => {
                '2->A' => [ 'coding_exon_stats' ],
                'A->1' => [ 'coding_exon_stats_summary' ],
            },
            -rc_name    => '2Gb_job',
        },

        {   -logic_name    => 'coding_exon_stats',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonStats',
            -hive_capacity => 5,
            -rc_name       => '2Gb_job',
        },

        {   -logic_name => 'coding_exon_stats_summary',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerCodingExonSummary',
            -rc_name    => '1Gb_job',
        },
    ];
}


1;
