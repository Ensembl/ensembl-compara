## Configuration file for the Epo Low Coverage pipeline

package Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'},

	'release'       => 67,
	'prev_release'  => 66,
        'release_suffix'=> '', # set it to '' for the actual release
        'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
        'pipeline_name' => 'LOW35_'.$self->o('release').$self->o('release_suffix'), # name used by the beekeeper to prefix job names on the farm

	#location of new pairwise mlss if not in the pairwise_default_location eg:
	'pairwise_exception_location' => { 576 => 'mysql://ensro@compara1/sf5_hsap_stri_lastz_67'},
	#'pairwise_exception_location' => { },

        'host' => 'compara1',
        'pipeline_db' => {
            -host   => $self->o('host'),
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $ENV{USER}.'_epo_35way_'.$self->o('release').$self->o('release_suffix'),
        },

	#Location of compara db containing most pairwise mlss ie previous compara
	'live_compara_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -dbname => 'mm14_ensembl_compara_67',
#	    -dbname => 'ensembl_compara_' . $self->o('prev_release'),
	    -driver => 'mysql',
        },

	#Location of compara db containing the high coverage alignments
	'epo_db' => 'mysql://ensro@compara3:3306/sf5_compara_epo_12way_68',

	master_db => { 
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'sf5_ensembl_compara_master',
	    -driver => 'mysql',
        },
	'populate_new_database_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",

	'staging_loc1' => {
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('release'),
        },
        'staging_loc2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('release'),
        },  
	'livemirror_loc' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('prev_release'),
        },

	'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),   #mlss_id for low coverage epo alignment
	'high_epo_mlss_id' => $self->o('high_epo_mlss_id'), #mlss_id for high coverage epo alignment
	'ce_mlss_id' => $self->o('ce_mlss_id'),             #mlss_id for low coverage constrained elements
	'cs_mlss_id' => $self->o('cs_mlss_id'),             #mlss_id for low coverage conservation scores
	#'master_db_name' => 'sf5_ensembl_compara_master',   
	'ref_species' => 'homo_sapiens',                    #ref species for pairwise alignments
	'max_block_size'  => 1000000,                       #max size of alignment before splitting 
	'pairwise_default_location' => $self->dbconn_2_url('live_compara_db'), #default location for pairwise alignments

        'step' => 10000, #size used in ImportAlignment for selecting how many entries to copy at once

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate (and slow) method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
	'quick' => 1,

	 #gerp parameters
	'gerp_version' => '2.1',                            #gerp program version
	'gerp_window_sizes'    => '[1,10,100,500]',         #gerp window sizes
	'no_gerp_conservation_scores' => 0,                 #Not used in productions but is a valid argument
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh', #location of full species tree, will be pruned 
	'newick_format' => 'simple',
	'work_dir' => $self->o('work_dir'),                 #location to put pruned tree file 
        'species_to_skip' => undef,

	#Location of executables (or paths to executables)
	'gerp_exe_dir'    => '/software/ensembl/compara/gerp/GERPv2.1',   #gerp program
        'semphy_exe'      => '/software/ensembl/compara/semphy_latest', #semphy program
        'treebest_exe'      => '/software/ensembl/compara/treebest.doubletracking', #treebest program
        'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
        'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

        #
        #Default statistics
        #
        'skip_multiplealigner_stats' => 0, #skip this module if set to 1
        'bed_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/epo_low_coverage/bed_dir/' . 'release_' . $self->o('rel_with_suffix') . '/',
        'output_dir' => '/lustre/scratch110/ensembl/' . $ENV{USER} . '/epo_low_coverage/feature_dumps/' . 'release_' . $self->o('rel_with_suffix') . '/',

        #
        #Resource requirements
        #
       'memory_suffix' => "", #temporary fix to define the memory requirements in resource_classes
       'dbresource'    => 'my'.$self->o('host'), # will work for compara1..compara4, but will have to be set manually otherwise
       'aligner_capacity' => 2000,
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
       'mkdir -p '.$self->o('output_dir'), #Make dump_dir directory
       'mkdir -p '.$self->o('bed_dir'), #Make bed_dir directory
	   ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
            %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
    };
}

sub resource_classes {
    my ($self) = @_;

    return {
         %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         '100Mb' => { 'LSF' => '-C0 -M100' . $self->o('memory_suffix') .' -R"select[mem>100] rusage[mem=100]"' },
         '1Gb'   => { 'LSF' => '-C0 -M1000' . $self->o('memory_suffix') .' -R"select[mem>1000 && '.$self->o('dbresource').'<'.$self->o('aligner_capacity').'] rusage[mem=1000,'.$self->o('dbresource').'=10:duration=3]"' },
	 '1.8Gb' => { 'LSF' => '-C0 -M1800' . $self->o('memory_suffix') .' -R"select[mem>1800] rusage[mem=1800]"' },
         '3.6Gb' =>  { 'LSF' => '-C0 -M3600' . $self->o('memory_suffix') .' -R"select[mem>3600] rusage[mem=3600]"' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_program'),
				  'mlss_id'        => $self->o('low_epo_mlss_id'),
				  'ce_mlss_id'     => $self->o('ce_mlss_id'),
				  'cs_mlss_id'     => $self->o('cs_mlss_id'),
				  'cmd'            => "#program# --master " . $self->dbconn_2_url('master_db') . " --new " . $self->dbconn_2_url('pipeline_db') . " --mlss #mlss_id# --mlss #ce_mlss_id# --mlss #cs_mlss_id# ",
				 },
               -input_ids => [{}],
	       -flow_into => {
			      1 => [ 'set_mlss_tag' ],
			     },
		-rc_name => '1Gb',
	    },

# -------------------------------------------[Set conservation score method_link_species_set_tag ]------------------------------------------
            { -logic_name => 'set_mlss_tag',
              -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
              -parameters => {
                              'sql' => [ 'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (' . $self->o('cs_mlss_id') . ', "msa_mlss_id", ' . $self->o('low_epo_mlss_id') . ')' ],
                             },
              -flow_into => {
                             1 => [ 'set_internal_ids' ],
                            },
              -rc_name => '100Mb',
            },

# ------------------------------------------------------[Set internal ids ]---------------------------------------------------------------
	    {   -logic_name => 'set_internal_ids',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),
				'sql'   => [
					    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					   ],
			       },
		-flow_into => {
			       1 => [ 'load_genomedb_factory' ],
			      },
		-rc_name => '100Mb',
	    },

# ---------------------------------------------[Load GenomeDB entries from master+cores]--------------------------------------------------
	    {   -logic_name => 'load_genomedb_factory',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
		-parameters => {
				'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
				'mlss_id'       => $self->o('low_epo_mlss_id'),
				'call_list'             => [ 'compara_dba', 'get_MethodLinkSpeciesSetAdaptor', ['fetch_by_dbID', '#mlss_id#'], 'species_set_obj', 'genome_dbs'],

				'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },
				
				'fan_branch_code'       => 2,
			       },
		-flow_into => {
			       '2->A' => [ 'load_genomedb' ],
			       'A->1' => [ 'load_genomedb_funnel' ],    # backbone
			      },
		-rc_name => '100Mb',
	    },
	    {   -logic_name => 'load_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-parameters => {
				'registry_dbs'  => [ $self->o('staging_loc1'), $self->o('staging_loc2'), $self->o('livemirror_loc')],
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
		-rc_name => '100Mb',
	    },

	    {   -logic_name => 'load_genomedb_funnel',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -meadow_type=> 'LOCAL',
		-flow_into => {
                    '1->A' => {
                               'make_species_tree' => [
                                                       {'blength_tree_file' => $self->o('species_tree_file'), 'newick_format' => 'simple' }, #species_tree
                                                       {'newick_format'     => 'njtree' },                                                   #taxon_tree
                                                       ],
                               },

		    'A->1' => [ 'create_default_pairwise_mlss'],
		},
		-rc_name => '100Mb',
        },
# -------------------------------------------------------------[Load species tree]--------------------------------------------------------
	    {   -logic_name    => 'make_species_tree',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
		-parameters    => { 
				   'mlss_id' => $self->o('low_epo_mlss_id'),
				  },
	        -flow_into  => {
                   3 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'taxon_tree', 'value' => '#species_tree_string#' } },
		   4 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },

                },
		-rc_name => '100Mb',
	    },

# -----------------------------------[Create a list of pairwise mlss found in the default compara database]-------------------------------
	    {   -logic_name => 'create_default_pairwise_mlss',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::CreateDefaultPairwiseMlss',
		-parameters => {
				'new_method_link_species_set_id' => $self->o('low_epo_mlss_id'),
				'base_method_link_species_set_id' => $self->o('high_epo_mlss_id'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
				#'base_location' => $self->dbconn_2_url('epo_db'),
				'base_location' => $self->o('epo_db'),
				'reference_species' => $self->o('ref_species'),
				'fan_branch_code' => 3,
			       },
		-flow_into => {
			       1 => [ 'import_alignment' ],
			       3 => [ 'mysql:////meta' ],
			      },
		-rc_name => '100Mb',
	    },

# ------------------------------------------------[Import the high coverage alignments]---------------------------------------------------
	    {   -logic_name => 'import_alignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment',
		-parameters => {
				'method_link_species_set_id'       => $self->o('high_epo_mlss_id'),
				#'from_db_url'                      => $self->dbconn_2_url('epo_db'),
				'from_db_url'                      => $self->o('epo_db'),
                                'step'                             => $self->o('step'),
			       },
		-flow_into => {
			       1 => [ 'create_low_coverage_genome_jobs' ],
			      },
		-rc_name =>'1Gb',
	    },

# ------------------------------------------------------[Low coverage alignment]----------------------------------------------------------
	    {   -logic_name => 'create_low_coverage_genome_jobs',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery' => 'SELECT genomic_align_block_id FROM genomic_align ga LEFT JOIN dnafrag USING (dnafrag_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id') . ' AND genome_db_id <> 63 GROUP BY genomic_align_block_id',
				'fan_branch_code' => 2,
			       },
		-flow_into => {
			       '2->A' => [ 'low_coverage_genome_alignment' ],
			       'A->1' => [ 'delete_alignment' ],
			      },
		-rc_name => '100Mb',
	    },
	    {   -logic_name => 'low_coverage_genome_alignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'mlss_id' => $self->o('low_epo_mlss_id'),
				'reference_species' => $self->o('ref_species'),
				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
                                'semphy_exe' => $self->o('semphy_exe'),
                                'treebest_exe' => $self->o('treebest_exe'),
			       },
		-batch_size      => 5,
		-hive_capacity   => 30,
		#Need a mode to say, do not die immediately if fail due to memory because of memory leaks, rerunning is the solution. Flow to module _again.
		-flow_into => {
			       2 => [ 'gerp' ],
			       -1 => [ 'low_coverage_genome_alignment_again' ],
			      },
		-rc_name => '1.8Gb',
	    },
	    #If fail due to MEMLIMIT, probably due to memory leak, and rerunning with the default memory should be fine.
	    {   -logic_name => 'low_coverage_genome_alignment_again',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'mlss_id' => $self->o('low_epo_mlss_id'),
				'reference_species' => $self->o('ref_species'),
				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
                                'semphy_exe' => $self->o('semphy_exe'),
                                'treebest_exe' => $self->o('treebest_exe'),
			       },
		-batch_size      => 5,
		-hive_capacity   => 30,
		-flow_into => {
			       2 => [ 'gerp' ],
			      },
		-rc_name => '1.8Gb',
	    },
# ---------------------------------------------------------------[Gerp]-------------------------------------------------------------------
	    {   -logic_name => 'gerp',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
		-parameters => {
				'program_version' => $self->o('gerp_version'),
				'window_sizes' => $self->o('gerp_window_sizes'),
				'gerp_exe_dir' => $self->o('gerp_exe_dir'),
			       },
		-hive_capacity   => 600,
		-rc_name => '1Gb',
	    },

# ---------------------------------------------------[Delete high coverage alignment]-----------------------------------------------------
	    {   -logic_name => 'delete_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'sql' => [
					  'DELETE gat, ga FROM genomic_align_tree gat JOIN genomic_align ga USING (node_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					  'DELETE FROM genomic_align_block WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					 ],
			       },
		-flow_into => {
			       1 => [ 'update_max_alignment_length' ],
			      },
		-rc_name => '100Mb',
	    },

# ---------------------------------------------------[Update the max_align data in meta]--------------------------------------------------
	    {  -logic_name => 'update_max_alignment_length',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	        -parameters => {
			       'quick' => $self->o('quick'),
			       'method_link_species_set_id' => $self->o('low_epo_mlss_id'),
			      },
	       -flow_into => {
			      1 => [ 'create_neighbour_nodes_jobs_alignment' ],
			     },
		-rc_name => '100Mb',
	    },

# --------------------------------------[Populate the left and right node_id of the genomic_align_tree table]-----------------------------
	    {   -logic_name => 'create_neighbour_nodes_jobs_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery' => 'SELECT root_id FROM genomic_align_tree WHERE parent_id = 0',
				'fan_branch_code' => 2,
			       },
		-flow_into => {
			       '2->A' => [ 'set_neighbour_nodes' ],
			       'A->1' => [ 'healthcheck_factory' ],
			      },
		-rc_name => '100Mb',
	    },
	    {   -logic_name => 'set_neighbour_nodes',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-parameters => {
				'method_link_species_set_id' => $self->o('low_epo_mlss_id')
			       },
		-batch_size    => 10,
		-hive_capacity => 15,
		-rc_name => '1.8Gb',
	    },
# -----------------------------------------------------------[Run healthcheck]------------------------------------------------------------
            {   -logic_name => 'healthcheck_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -meadow_type=> 'LOCAL',
                -flow_into => {
                               '2->A' => {
                                     'conservation_score_healthcheck'  => [
                                                                           {'test' => 'conservation_jobs', 'logic_name'=>'gerp','method_link_type'=>'EPO_LOW_COVERAGE'}, 
                                                                           {'test' => 'conservation_scores','method_link_species_set_id'=>$self->o('cs_mlss_id')},
                                                                ],
                                    },
                               'A->1' => ['stats_factory'],
                              },
            },

	    {   -logic_name => 'conservation_score_healthcheck',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
		-rc_name => '100Mb',
	    },

            {   -logic_name => 'stats_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
                -parameters => {
                                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                                'column_names2getters'  => { 'genome_db_id' => 'dbID' },
                                
                                'fan_branch_code'       => 2,
                               },
                -flow_into  => {
                                2 => [ 'multiplealigner_stats' ],
                               },
            },
            
            { -logic_name => 'multiplealigner_stats',
	      -module => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
	      -parameters => {
			      'skip' => $self->o('skip_multiplealigner_stats'),
			      'dump_features' => $self->o('dump_features_exe'),
			      'compare_beds' => $self->o('compare_beds_exe'),
			      'bed_dir' => $self->o('bed_dir'),
			      'ensembl_release' => $self->o('release'),
			      'output_dir' => $self->o('output_dir'),
                              'mlss_id'   => $self->o('low_epo_mlss_id'),
			     },
	      -rc_name => '3.6Gb',             
              -hive_capacity => 100,  
            },

     ];
}
1;
