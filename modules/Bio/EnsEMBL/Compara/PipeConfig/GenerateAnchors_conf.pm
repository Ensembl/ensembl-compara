## Generic configuration module for all Compara pipelines

package Bio::EnsEMBL::Compara::PipeConfig::GenerateAnchors_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
        'pipeline_name' => 'compara_GenerateAnchors',
	'ensembl_cvs_root_dir' => '/nfs/users/nfs_s/sf5/src',
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
	   # parameters that are likely to change from execution to another:
	'release'               => '62',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
	'password' 		=> 'ensembl',
	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara3',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $ENV{'USER'}.'_compara_generate_anchors'.$self->o('rel_with_suffix'),
   	},
	'compara_pairwise_db' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'ens-livemirror',
		-pass => '',
		-dbname => 'ensembl_compara_62',
	},
	'core_db_url' => 'mysql://anonymous@ensembldb.ensembl.org:5306/62',
     };
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
           ];  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'compara_pairwise_db' => $self->o('compara_pairwise_db'),
		'min_anchor_size'     => 50,
		'min_number_of_org_hits_per_base' => 2,
	        'reference_genome_db_id' => 90,
		'reference_db' => {
				-user => 'ensro',
				-port => 3306,
				-group => 'core',
				-species => 'homo_sapiens',
				-host => "ens-livemirror",
				-dbname => 'homo_sapiens_core_61_37f',
				},
	};
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";
	
		
    return [
# Turn all tables except 'genome_db' to InnoDB
	    {   -logic_name => 'innodbise_table_factory',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
				'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='" . 
						$self->o('pipeline_db','-dbname') .
						"' AND table_name!='genome_db' AND engine='MyISAM' ",
				'input_id'        => { 'table_name' => '#_range_start#' },
				'fan_branch_code' => 2,
			       },
		-input_ids => [{}],
		-flow_into => {
			       2 => [ 'innodbise_table' ],
			      },
	    },

	    {   -logic_name    => 'innodbise_table',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters    => {
				   'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
				  },
		-hive_capacity => 1,
	    },

	    {	-logic_name	=> 'chunk_reference_dnafrags',
		-module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnafrags',
		-parameters	=> {
				    'compara_db' => $self->o('compara_pairwise_db'),
				    'method_link_types' => [ 'BLASTZ_NET', 'LASTZ_NET'],
				    'chunk_size' => '10000000',
				    'consensus_overlap' => 0,
				    'genome_db_ids' => [39, 64, 93],
#				    'genome_db_ids' => [],
				   },
		-input_ids 	=> [{}],
		-wait_for       => [ 'innodbise_table_factory', 'innodbise_table' ],	
		-flow_into	=> {
					2 => [ 'find_pairwise_overlaps' ],
					3 => [ 'import_entries' ],
					4 => [ 'mysql:////meta' ],
				   },
				 
	    },

	    {   -logic_name => 'import_entries',
	        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
    	        -parameters => {
	            'src_db_conn'   => $self->o('compara_pairwise_db'),
	            'where'         => 'genome_db_id IN (#genome_dbs_csv#)',
	        },
		-flow_into      => {
					2 => [ 'load_species_tree' ],
					3 => [ 'set_genome_db_locator' ],
		},
	    },
	    {
		-logic_name     => 'set_genome_db_locator',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::SetGenomeDBLocator',
		-parameters     => { 'core_db_url' => $self->o('core_db_url') },
		-input_ids => [{}],
		-wait_for       => [ 'import_entries' ],
		-flow_into => {
				2 => [ 'mysql:////genome_db?insertion_method=REPLACE' ],
		}
	
	    },
	    {
		-logic_name => 'load_species_tree',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
			'inputcmd'        => 'cat ' . $self->o('species_tree_file') . ' | tr \'[A-Z]\' \'[a-z]\'',
			'input_id'        => { 'meta_key' => 'tree_string', 'meta_value' => '#_range_start#' },
			'fan_branch_code' => 2,
		},
		-input_ids      => [{}],
		-flow_into => {
				2 => [ 'mysql:////meta' ],
		},
		-wait_for       => [ 'import_entries' ],
	   },
		
	   {
		-logic_name	=> 'find_pairwise_overlaps',
		-module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps',
		-parameters     => { 'method_link_species_set_id' => 300, },
		-wait_for	=> [ 'import_entries' ],
		-flow_into	=> {
					1 => [ 'pecan' ],
					3 => [ 'mysql:////dnafrag_region?insertion_method=INSERT_IGNORE' ],
				   },
		-hive_capacity => 100,
	   },

	   {
		-logic_name    => 'pecan',
		-module        => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan',
		-wait_for      => 'find_pairwise_overlaps',
		-parameters     => { 'method_link_species_set_id' => 400, },
		-hive_capacity => 100,
	   },
	];
}	


1;
