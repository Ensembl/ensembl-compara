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

		'compara_pairwise_db' => {
				-user => 'ensro',
				-port => '3306',
				-group => 'compara',
				-species => 'Multi',
				-host => 'ens-livemirror',
				-dbname => 'ensembl_compara_61',
				},
					
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
				'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='genome_db' AND engine='MyISAM' ",
				'input_id'        => { 'table_name' => '#_range_start#' },
				'fan_branch_code' => 2,
			       },
		-input_ids => [{}],
		-flow_into => {
			       2 => [ 'innodbise_table'  ],
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
				    'method_link_type' => 'BLASTZ_NET:LASTZ_NET',
				    'chunk_size' => '10000000',
				    'consensus_overlap' => 0,
				#    'genome_db_ids' => [38, 101],
				    'genome_db_ids' => [],
				   },
		-input_ids 	=> [{}],
		-wait_for       => [ 'innodbise_table_factory', 'innodbise_table' ],	
		-flow_into	=> {
					2 => [ 'find_pairwise_overlaps' ],
				   },
				 
	    },
	    
	    {
		-logic_name	=> 'find_pairwise_overlaps',
		-module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps',
		-wait_for	=> 'chunk_reference_dnafrags',
		-parameters     => { 'method_link_species_set_id' => 300, },
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

