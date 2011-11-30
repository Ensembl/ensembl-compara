## Configuration file for the Epo Low Coverage pipeline

package Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
	%{$self->SUPER::default_options},   # inherit the generic ones

        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/src/ensembl_main/', 

	'release'       => 65,
	'prev_release'  => 64,
        'release_suffix'=> '', # set it to '' for the actual release
        'pipeline_name' => 'LOW35_'.$self->o('release').$self->o('release_suffix'), # name used by the beekeeper to prefix job names on the farm

	#location of new pairwise mlss if not in the pairwise_default_location eg:
	'pairwise_exception_location' => { 545 => 'mysql://ensro@compara1/kb3_hsap_ogar_lastz_65'},
	#'pairwise_exception_location' => { },

        'pipeline_db' => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $ENV{USER}.'_epo_35way_'.$self->o('release').$self->o('release_suffix'),
        },

	#Location of compara db containing most pairwise mlss ie previous compara
	'live_compara_db' => {
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
#	    -dbname => 'ensembl_compara_63',
	    -dbname => 'ensembl_compara_' . $self->o('prev_release'),
	    -driver => 'mysql',
        },

	#Location of compara db containing the high coverage alignments
	#Make this a url that you provide on the command line
	#'epo_db' => {
        #    -host   => 'compara3',
        #    -port   => 3306,
        #    -user   => 'ensro',
        #    -pass   => '',
	#    -dbname => 'sf5_compara_12way_64',
	#    -driver => 'mysql',
        #},
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

	 #gerp parameters
	'gerp_version' => '2.1',                            #gerp program version
	'gerp_window_sizes'    => '[1,10,100,500]',         #gerp window sizes
	'no_gerp_conservation_scores' => 0,                 #Not used in productions but is a valid argument
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh', #location of full species tree, will be pruned 
	'newick_format' => 'simple',
	'work_dir' => $self->o('work_dir'),                 #location to put pruned tree file 

	#Location of executables (or paths to executables)
	'gerp_exe_dir'    => '/software/ensembl/compara/gerp/GERPv2.1',   #gerp program
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
	   ];
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;

    return {
	    'pipeline_name' => $self->o('pipeline_name'), #Essential for the beekeeper to work correctly
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
         #0 => { -desc => 'default, 8h',      'LSF' => '' },
	 0 => { -desc => 'default',           'LSF' => '-R"select[mycompara1 <=800 && myens_staging1 <= 800 && myens_staging2 <=800 && myens_livemirror <=800] rusage[mycompara1=10:duration=3,myens_staging1=10:duration=3,myens_staging2=10:duration=3,myens_livemirror=10:duration=3]"' },
	 1 => { -desc => 'urgent',           'LSF' => '-q yesterday' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    #my $epo_low_coverage_logic_name = $self->o('logic_name_prefix');

    print "pipeline_analyses\n";

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
			       1 => [ 'populate_new_database' ],
			      },
	    },

	    {   -logic_name    => 'innodbise_table',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
				   'sql'         => "ALTER TABLE #table_name# ENGINE='InnoDB'",
				  },
		-hive_capacity => 10,
		-can_be_empty  => 1
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_program'),
				  #'master'         => $self->o('master_db_name'),
				  'mlss_id'        => $self->o('low_epo_mlss_id'),
				  'ce_mlss_id'     => $self->o('ce_mlss_id'),
				  'cs_mlss_id'     => $self->o('cs_mlss_id'),
				  'cmd'            => "#program# --master " . $self->dbconn_2_url('master_db') . " --new " . $self->dbconn_2_url('pipeline_db') . " --mlss #mlss_id# --mlss #ce_mlss_id# --mlss #cs_mlss_id# ",
				 },
	       -wait_for  => [ 'innodbise_table' ],
	       -flow_into => {
			      1 => [ 'set_internal_ids' ],
			     },
	    },

# ------------------------------------------------------[Set internal ids ]---------------------------------------------------------------
	    {   -logic_name => 'set_internal_ids',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'low_epo_mlss_id' => $self->o('low_epo_mlss_id'),
				'sql'   => [
					    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align_group AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					    'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr(($low_epo_mlss_id * 10**10) + 1)expr#',
					   ],
			       },
		-flow_into => {
			       1 => [ 'load_genomedb_factory' ],
			      },
	    },

# ---------------------------------------------[Load GenomeDB entries from master+cores]--------------------------------------------------
	    {   -logic_name => 'load_genomedb_factory',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
		-parameters => {
				'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
				'mlss_id'       => $self->o('low_epo_mlss_id'),
				
				'adaptor_name'          => 'MethodLinkSpeciesSetAdaptor',
				'adaptor_method'        => 'fetch_by_dbID',
				'method_param_list'     => [ '#mlss_id#' ],
				'object_method'         => 'species_set',
				
				'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },
				
				'fan_branch_code'       => 2,
			       },
		-flow_into => {
			       2 => [ 'load_genomedb' ],
			       1 => [ 'load_genomedb_funnel' ],    # backbone
			      },
	    },
	    {   -logic_name => 'load_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-parameters => {
				'registry_dbs'  => [ $self->o('staging_loc1'), $self->o('staging_loc2'), $self->o('livemirror_loc')],
#				'registry_dbs'  => [ $self->o('live_db'), $self->o('reg1'), $self->o('reg2')],
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
	    },

	    {   -logic_name => 'load_genomedb_funnel',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
		-wait_for => [ 'load_genomedb' ],
		-flow_into => {
		    1 => [ 'create_default_pairwise_mlss'],
		},
        },
# -------------------------------------------------------------[Load species tree]--------------------------------------------------------
	    {   -logic_name    => 'make_species_tree',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
		-parameters    => { },
		-input_ids     => [
				   {'blength_tree_file' => $self->o('species_tree_file'), 'newick_format' => 'simple' }, #species_tree
				   {'newick_format'     => 'njtree' },                                                   #taxon_tree
				  ],
		-hive_capacity => -1,   # to allow for parallelization
		-wait_for => [ 'load_genomedb_funnel' ],
	        -flow_into  => {
                   3 => { 'mysql:////meta' => { 'meta_key' => 'taxon_tree', 'meta_value' => '#species_tree_string#' } },
                   4 => { 'mysql:////meta' => { 'meta_key' => 'tree_string', 'meta_value' => '#species_tree_string#' } },
                },
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
			      }
	    },

# ------------------------------------------------[Import the high coverage alignments]---------------------------------------------------
	    {   -logic_name => 'import_alignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment',
		-parameters => {
				'method_link_species_set_id'       => $self->o('high_epo_mlss_id'),
				#'from_db_url'                      => $self->dbconn_2_url('epo_db'),
				'from_db_url'                      => $self->o('epo_db'),
			       },
		-wait_for  => [ 'create_default_pairwise_mlss', 'make_species_tree'],
		-flow_into => {
			       1 => [ 'create_low_coverage_genome_jobs' ],
			      },
	    },

# ------------------------------------------------------[Low coverage alignment]----------------------------------------------------------
	    {   -logic_name => 'create_low_coverage_genome_jobs',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery' => 'SELECT genomic_align_block_id FROM genomic_align ga LEFT JOIN dnafrag USING (dnafrag_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id') . ' AND genome_db_id <> 63 GROUP BY genomic_align_block_id',
				'fan_branch_code' => 2,
			       },
		-flow_into => {
			       1 => [ 'delete_alignment' ],
			       2 => [ 'low_coverage_genome_alignment' ],
			      }
	    },
	    {   -logic_name => 'low_coverage_genome_alignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'method_link_species_set_id' => $self->o('low_epo_mlss_id'),
				'reference_species' => $self->o('ref_species'),
				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
			       },
		-batch_size      => 5,
		-hive_capacity   => 30,
		#Need a mode to say, do not die immediately if fail due to memory because of memory leaks, rerunning is the solution. Flow to module _again.
		-flow_into => {
			       2 => [ 'gerp' ],
			       -1 => [ 'low_coverage_genome_alignment_again' ],
			      },
	    },
	    #If fail due to MEMLIMIT, probably due to memory leak, and rerunning with the default memory should be fine.
	    {   -logic_name => 'low_coverage_genome_alignment_again',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::LowCoverageGenomeAlignment',
		-parameters => {
				'max_block_size' => $self->o('max_block_size'),
				'method_link_species_set_id' => $self->o('low_epo_mlss_id'),
				'reference_species' => $self->o('ref_species'),
				'pairwise_exception_location' => $self->o('pairwise_exception_location'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
			       },
		-batch_size      => 5,
		-hive_capacity   => 30,
		-flow_into => {
			       2 => [ 'gerp' ],
			      },
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
	    },

# ---------------------------------------------------[Delete high coverage alignment]-----------------------------------------------------
	    {   -logic_name => 'delete_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'sql' => [
					  'DELETE gag, gat, ga FROM genomic_align_group gag JOIN genomic_align_tree gat USING (node_id) JOIN genomic_align ga USING (genomic_align_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					  'DELETE FROM genomic_align_block WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					 ],
			       },
		#-input_ids => [{}],
		-wait_for  => [ 'low_coverage_genome_alignment', 'gerp' ],
		-flow_into => {
			       1 => [ 'update_max_alignment_length' ],
			      },
	    },

# ---------------------------------------------------[Update the max_align data in meta]--------------------------------------------------
	    {  -logic_name => 'update_max_alignment_length',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	       -flow_into => {
			      1 => [ 'create_neighbour_nodes_jobs_alignment' ],
			     },
	    },

# --------------------------------------[Populate the left and right node_id of the genomic_align_tree table]-----------------------------
	    {   -logic_name => 'create_neighbour_nodes_jobs_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery' => 'SELECT root_id FROM genomic_align_tree WHERE parent_id = 0',
				'fan_branch_code' => 2,
			       },
		-flow_into => {
			       1 => [ 'conservation_score_healthcheck' ],
			       2 => [ 'set_neighbour_nodes' ],
			      }
	    },
	    {   -logic_name => 'set_neighbour_nodes',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-parameters => {
				'method_link_species_set_id' => $self->o('low_epo_mlss_id')
			       },
		-batch_size    => 10,
		-hive_capacity => 15,
	    },
# -----------------------------------------------------------[Run healthcheck]------------------------------------------------------------
	    {   -logic_name => 'conservation_score_healthcheck',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
		-wait_for   => [ 'set_neighbour_nodes' ],
		-input_ids  => [
				{'test' => 'conservation_jobs', 'logic_name'=>'gerp','method_link_type'=>'EPO_LOW_COVERAGE'}, 
				{'test' => 'conservation_scores','method_link_species_set_id'=>$self->o('cs_mlss_id')},
			       ],
	    },

     ];
}
1;
