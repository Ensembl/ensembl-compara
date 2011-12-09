
package Bio::EnsEMBL::Compara::PipeConfig::GenerateAnchors_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
        'pipeline_name' => 'compara_GenerateAnchors',
	'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
	   # parameters that are likely to change from execution to another:
	'release'               => '72',
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
		-dbname => $ENV{'USER'}.'_compara_fish_anchors'.$self->o('rel_with_suffix'),
   	},
	  # database containing the pairwise alignments needed to get the overlaps
	'compara_pairwise_db' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'ens-livemirror',
		-pass => '',
		-dbname => 'ensembl_compara_62',
	},
	  # genome_db_id from which pairwise alignments will be used
	'reference_genome_db_id' => 110,
	  # pairwise alignments from these non-ref genome_db_ids and the reference_genome_db_id will be use to build the anchors
	  # if it's an empty string then all pairwise alignments with the reference_genome_db_id will be used
	'non_ref_genome_db_ids' => [4,37,65,36],
#	'non_ref_genome_db_ids' => [],
	  # location of species core dbs which were used in the pairwise alignments
	'core_db_url' => 'mysql://ensro@ens-livemirror:3306/62',
	  # alignment chunk size
	'chunk_size' => 10000000,
	  # max block size for pecan to align
	'pecan_block_size' => 1000000,
	'pecan_mlssid' => 10,
	'gerp_constrained_element_mlssid' => 20,
	'gerp_program_file'    => '/software/ensembl/compara/gerp/GERPv2.1',
	'find_pairwise_overlaps_mlssid' => 0, # does not matter what you set it to as long as it does not clash with an other mlssid used in the pipeline
	'species_tree_dump_dir' => '/nfs/users/nfs_s/sf5/Fish/Tree/', # dir to dump species tree for gerp
	'max_frag_diff' => 1.5, # max difference in sizes between non-reference dnafrag and reference to generate the overlaps from
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
		'max_frag_diff' => $self->o('max_frag_diff'),
	        'reference_genome_db_id' => $self->o('reference_genome_db_id'),
		'reference_db' => {
				-user => 'ensro',
				-port => 3306,
				-group => 'core',
#				-species => 'homo_sapiens',
				-species => 'danio_rerio',
				-host => "ens-livemirror",
#				-dbname => 'homo_sapiens_core_62_37g',
				-dbname => 'danio_rerio_core_62_9b',
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
				'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='" . $self->o('pipeline_db','-dbname') . "' AND table_name!='genome_db' AND engine='MyISAM' ",
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
				    'method_link_types' => [ 'TRANSLATED_BLAT_NET' ],
#				    'method_link_types' => [ 'BLASTZ_NET', 'LASTZ_NET'],
				    'chunk_size' => $self->o('chunk_size'),
				    'genome_db_ids' => $self->o('non_ref_genome_db_ids'),
				   },
		-input_ids 	=> [{}],
		-wait_for       => [ 'innodbise_table' ],	
		-flow_into	=> {
					1 => [ 'find_pairwise_overlaps' ],
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
		},
	    },
	    {
		-logic_name     => 'load_method_link_table',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
		-input_ids => [{}],
		-parameters => {
			'src_db_conn'   => $self->o('compara_pairwise_db'),
			'table'         => 'method_link',
		},
		-flow_into => {
			2 => [ 'mysql:////method_link?insertion_method=IGNORE' ],
		},
	    },
	    { # this sets the values in the method_link_species_set and species_set tables
		-logic_name     => 'populate_compara_tables',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::LoadMethodTables',
		-wait_for       => [ 'load_method_link_table', 'set_genome_db_locator' ],
		-input_ids => [{'species_set_id' => 1, 'mlss_ids' => {'PECAN_mlssid' => $self->o('pecan_mlssid'), 
							'GERP_CONSTRAINED_ELEMENT_mlssid' => $self->o('gerp_constrained_element_mlssid'),},}],	
		-flow_into => {
			2 => [ 'mysql:////species_set?insertion_method=INSERT_IGNORE' ],
			3 => [ 'mysql:////method_link_species_set?insertion_method=INSERT_IGNORE' ],
		},
	    },
	    {
		-logic_name => 'load_species_tree',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
			'inputcmd'        => 'cat ' . $self->o('species_tree_file') . ' | tr \'[A-Z]\' \'[a-z]\'',
            'column_names'    => [ 'the_tree_itself' ],
			'input_id'        => { 'meta_key' => 'tree_string', 'meta_value' => '#the_tree_itself#' },
			'fan_branch_code' => 2,
		},
		-input_ids      => [{}],
		-flow_into => {
				2 => [ 'mysql:////meta' ],
		},
	   },
	   {
		-logic_name    => 'dump_species_tree',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
		-input_ids     => [ {
			'cmd'        => 'cat ' . $self->o('species_tree_file') . ' | tr \'[A-Z]\' \'[a-z]\' > ' .
						 $self->o('species_tree_dump_dir') . '/species_tree',
		} ],
	   },		
	   {
		-logic_name	=> 'find_pairwise_overlaps',
		-module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps',
		-wait_for      => [ 'chunk_reference_dnafrags' ],
		-parameters     => { 'method_link_species_set_id' => $self->o('find_pairwise_overlaps_mlssid'), },
		-flow_into	=> {
					2 => [ 'pecan' ],
					3 => [ 'mysql:////dnafrag_region?insertion_method=INSERT_IGNORE' ],
				   },
		-hive_capacity => 100,
	   },
	   {
		-logic_name    => 'pecan',
		-module        => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan',
		-wait_for      => [ 'populate_compara_tables', 'load_species_tree', ],
		-parameters    => { 'method_link_species_set_id' => $self->o('pecan_mlssid'), 
				    'max_block_size' => $self->o('pecan_block_size'),
				    'java_options' => '-server -Xmx1000M',},
		-flow_into      => {
					1 => [ 'gerp_constrained_element' ],
				   },
		-hive_capacity => 50,
		-failed_job_tolerance => 5, # % of jobs allowed to fail
   	   },

            #
            # Please consider switching to a newer version of Gerp module, 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp'
            # (it has slightly different input parameters and doesn't need '-program_file' anymore)
            #
	   {
		-logic_name    => 'gerp_constrained_element',
		-module => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp',
		-parameters    => { 'window_sizes' => '[1,10,100,500]', 'tree_file' => $self->o('species_tree_dump_dir') . '/species_tree',
				    'constrained_element_method_link_type' => 'GERP_CONSTRAINED_ELEMENT', },
		-program_file  => $self->o('gerp_program_file'),
		-wait_for      => [ 'dump_species_tree' ],
		-hive_capacity => 50,
		-batch_size    => 5,
	   },
				
    ];
}	


1;
