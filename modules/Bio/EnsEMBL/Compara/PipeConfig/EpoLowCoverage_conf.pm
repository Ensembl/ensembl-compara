## Configuration file for the Epo Low Coverage pipeline

package Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly

sub default_options {
    my ($self) = @_;
    return {
        'ensembl_cvs_root_dir' => $ENV{'HOME'}.'/src/ensembl_main/', 

	'release'       => 63,
	'prev_release'  => 62,
        'release_suffix'=> '', # set it to '' for the actual release
        'pipeline_name' => 'LOW35_'.$self->o('release').$self->o('release_suffix'), # name used by the beekeeper to prefix job names on the farm

	#location of new pairwise mlss if not in the pairwise_default_location eg:
	#'pairwise_exception_location' => { 517 => 'mysql://ensro@compara4/kb3_hsap_nleu_lastz_62'},
	'pairwise_exception_location' => { 521 => 'mysql://ensro@compara1/kb3_hsap_mluc_lastz_63'},

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
	    -dbname => 'ensembl_compara_62',
	    -driver => 'mysql',
        },

	#Location of compara db containing the high coverage alignments
	'epo_db' => {
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -dbname => 'sf5_63compara_ortheus12way',
	    -driver => 'mysql',
        },
	master_db => { 
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => 'sf5_ensembl_compara_master',
	    -driver => 'mysql',
        },
	'populate_new_database_program' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/populate_new_database.pl",

	'reg1' => {
            -host   => 'ens-staging1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('release'),
        },
        'reg2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
	    -db_version => $self->o('release'),
        },  
	'live_db' => {
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
	'master_db_name' => 'sf5_ensembl_compara_master',   
	'ref_species' => 'homo_sapiens',                    #ref species for pairwise alignments
	'max_block_size'  => 1000000,                       #max size of alignment before splitting 
	'pairwise_default_location' => $self->dbconn_2_url('live_compara_db'), #default location for pairwise alignments
	'gerp_version' => '2.1',                                               #gerp program version
	'gerp_program_file'    => '/software/ensembl/compara/gerp/GERPv2.1',   #gerp program
	'gerp_window_sizes'    => '[1,10,100,500]',                            #gerp window sizes
	'no_gerp_conservation_scores' => 0,                                    #Not used in productions but is a valid argument
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh', #location of full species tree, will be pruned 
	'newick_format' => 'simple',
	'work_dir' => $self->o('work_dir'),                 #location to put pruned tree file 
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
         0 => { -desc => 'default, 8h',      'LSF' => '' },
	 1 => { -desc => 'urgent',           'LSF' => '-q yesterday' },
         2 => { -desc => 'compara1',         'LSF' => '-R"select[compara1<800] rusage[compara1=10:duration=3]"' },
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
				'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='genome_db' AND engine='MyISAM' ",
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
	    },

# ---------------------------------------------[Run poplulate_new_database.pl script ]---------------------------------------------------
	    {  -logic_name => 'populate_new_database',
	       -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	       -parameters    => {
				  'program'        => $self->o('populate_new_database_program'),
				  'master'         => $self->o('master_db_name'),
				  'mlss_id'        => $self->o('low_epo_mlss_id'),
				  'ce_mlss_id'     => $self->o('ce_mlss_id'),
				  'cs_mlss_id'     => $self->o('cs_mlss_id'),
				  'cmd'            => "#program# --master " . $self->dbconn_2_url('master_db') . " --new " . $self->dbconn_2_url('pipeline_db') . " --mlss #mlss_id# --mlss #ce_mlss_id# --mlss #cs_mlss_id# ",
				 },
	       -wait_for  => [ 'innodbise_table_factory', 'innodbise_table' ],
	       -flow_into => {
			      1 => [ 'load_genomedb_factory' ],
			     },
	    },

# ---------------------------------------------[Load GenomeDB entries from master+cores]--------------------------------------------------
	    {  -logic_name => 'load_genomedb_factory',
	       -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadGenomedbFactory',
	       -parameters => {
			       'compara_db'    => $self->o('master_db'),   # that's where genome_db_ids come from
			       'mlss_id'       => $self->o('low_epo_mlss_id'),

			      },
	       -wait_for  => [ 'innodbise_table_factory', 'innodbise_table' ],
	       -flow_into => {
			      2 => ['load_genomedb' ],
			      1 => [ 'set_internal_ids' ],
			     },
	    },

	    {   -logic_name => 'load_genomedb',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-parameters => {
				'registry_dbs'  => [ $self->o('reg1'), $self->o('reg2'), $self->o('live_db')],
#				'registry_dbs'  => [ $self->o('live_db'), $self->o('reg1'), $self->o('reg2')],
			       },
		-hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
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
		-wait_for => [ 'load_genomedb' ],    # have to wait until genome_db table has been populated
		-flow_into => {
			       1 => [ 'ImportAlignment' , 'make_species_tree', 'CreateDefaultPairwiseMlss'],
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
	        -flow_into  => {
                   3 => { 'mysql:////meta' => { 'meta_key' => 'taxon_tree', 'meta_value' => '#species_tree_string#' } },
                   4 => { 'mysql:////meta' => { 'meta_key' => 'tree_string', 'meta_value' => '#species_tree_string#' } },
                },
	    },

# -----------------------------------[Create a list of pairwise mlss found in the default compara database]-------------------------------
	    {   -logic_name => 'CreateDefaultPairwiseMlss',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::CreateDefaultPairwiseMlss',
		-parameters => {
				'new_method_link_species_set_id' => $self->o('low_epo_mlss_id'),
				'base_method_link_species_set_id' => $self->o('high_epo_mlss_id'),
				'pairwise_default_location' => $self->o('pairwise_default_location'),
				'base_location' => $self->dbconn_2_url('epo_db'),
				'reference_species' => $self->o('ref_species'),
				'fan_branch_code' => 3,
			       },
		-flow_into => {
			       3 => [ 'mysql:////meta' ],
			      }
	    },

# ------------------------------------------------[Import the high coverage alignments]---------------------------------------------------
	    {   -logic_name => 'ImportAlignment',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment',
		-parameters => {
				'method_link_species_set_id'       => $self->o('high_epo_mlss_id'),
				'from_db_url'                      => $self->dbconn_2_url('epo_db'),
			       },
		-wait_for  => [ 'CreateDefaultPairwiseMlss', 'make_species_tree'],
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
			       2 => [ 'LowCoverageGenomeAlignment' ],
			      }
	    },
	    {   -logic_name => 'LowCoverageGenomeAlignment',
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
			       2 => [ 'Gerp' ],
			      },
	    },
# ---------------------------------------------------------------[Gerp]-------------------------------------------------------------------
	    {   -logic_name => 'Gerp',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
		-program_version => $self->o('gerp_version'),
		-program_file    => $self->o('gerp_program_file'),
		-parameters => {'window_sizes' => $self->o('gerp_window_sizes') },
		-hive_capacity   => 600,
	    },

# ---------------------------------------------------[Delete high coverage alignment]-----------------------------------------------------
	    {   -logic_name => 'delete_alignment',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'sql' => [
					  'DELETE genomic_align_tree FROM genomic_align_tree LEFT JOIN genomic_align_group USING (node_id) LEFT JOIN genomic_align USING (genomic_align_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					  'DELETE genomic_align_group FROM genomic_align_group LEFT JOIN genomic_align using (genomic_align_id) WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					  'DELETE FROM genomic_align WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					  'DELETE FROM genomic_align_block WHERE method_link_species_set_id=' . $self->o('high_epo_mlss_id'),
					 ],
			       },
		#-input_ids => [{}],
		-wait_for  => [ 'LowCoverageGenomeAlignment', 'Gerp' ],
		-flow_into => {
			       1 => [ 'UpdateMaxAlignmentLength' ],
			      },
	    },

# ---------------------------------------------------[Update the max_align data in meta]--------------------------------------------------
	    {  -logic_name => 'UpdateMaxAlignmentLength',
	       -module     => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
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
			       1 => [ 'ConservationScoreHealthCheck' ],
			       2 => [ 'SetNeighbourNodes' ],
			      }
	    },
	    {   -logic_name => 'SetNeighbourNodes',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-parameters => {
				'method_link_species_set_id' => $self->o('low_epo_mlss_id')
			       },
		-batch_size    => 10,
		-hive_capacity => 15,
	    },
# -----------------------------------------------------------[Run healthcheck]------------------------------------------------------------
	    {   -logic_name => 'ConservationScoreHealthCheck',
		-module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
		-wait_for   => [ 'SetNeighbourNodes' ],
		-input_ids  => [
				{'test' => 'conservation_jobs',
				 'params' => {'logic_name'=>'Gerp','method_link_type'=>'EPO_LOW_COVERAGE'}, 
				},
				{'test' => 'conservation_scores',
				 'params' => {'method_link_species_set_id'=>$self->o('cs_mlss_id')},
				},
			       ],
	    },

     ];
}
1;
