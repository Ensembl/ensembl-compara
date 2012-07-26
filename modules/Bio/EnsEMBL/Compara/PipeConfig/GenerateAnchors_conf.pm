
package Bio::EnsEMBL::Compara::PipeConfig::GenerateAnchors_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
	%{$self->SUPER::default_options},
        'pipeline_name' => 'compara_GenerateAnchors',
	'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
	   # parameters that are likely to change from execution to another:
	'release'               => '69',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
	'password' 		=> $ENV{'ENSADMIN_PSW'},
	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara4',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $ENV{'USER'}.'_seven_mammal_anchors_'.$self->o('rel_with_suffix'),
   	},
	  # database containing the pairwise alignments needed to get the overlaps
	'compara_pairwise_db' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'ens-livemirror',
		-pass => '',
		-dbname => 'ensembl_compara_67',
	},
	  # genome_db_id from which pairwise alignments will be used
	'reference_genome_db_id' => 90,
	  # pairwise alignments from these non-ref genome_db_ids and the reference_genome_db_id will be use to build the anchors
	  # if it's an empty string then all pairwise alignments with the reference_genome_db_id will be used
	'non_ref_genome_db_ids' => [39,61,57,3,132,108,122],
#	'non_ref_genome_db_ids' => [],
	  # location of species core dbs which were used in the pairwise alignments
	'core_db_urls' => [ 'mysql://ensro@ens-livemirror:3306/67' ],
	  # alignment chunk size
	'chunk_size' => 10000000,
	  # max block size for pecan to align
	'pecan_block_size' => 1000000,
	'pecan_method_link_id' => 10,
	'pecan_mlssid' => 10,
	'gerp_ce_mlid' => 11,
	'gerp_constrained_element_mlssid' => 20,
	'gerp_program_version' => "2.1",
	'gerp_exe_dir' => "/software/ensembl/compara/gerp/GERPv2.1",
	'species_set_id' => 10000, # species_set_id for reference and non-reference species
	'overlaps_method_link_id' => 10000, 
	'overlaps_method_link_name' => 'GEN_ANCS',
	'overlaps_mlssid' => 10000, 
	'species_tree_dump_dir' => '/nfs/users/nfs_s/sf5/Mammals/Tree/', # dir to dump species tree for gerp
	'max_frag_diff' => 1.5, # max difference in sizes between non-reference dnafrag and reference to generate the overlaps from
	'min_ce_length' => 40, # min length of each sequence in the constrained elenent 
	'max_anchor_seq_len' => 100,
     };
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
           ];  
}

sub resource_classes {
    my ($self) = @_; 
    return {
	%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
         'default' => {'LSF' => '-C0 -M2500000 -R"select[mem>2500] rusage[mem=2500]"' },
         'mem3500' => {'LSF' => '-C0 -M3500000 -R"select[mem>3500] rusage[mem=3500]"' },
         'mem7500' => {'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },  
         'mem14000' => {'LSF' => '-C0 -M14000000 -R"select[mem>14000] rusage[mem=14000]"' },  
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'compara_pairwise_db' => $self->o('compara_pairwise_db'),
        	'pecan_method_link_id' => $self->o('pecan_method_link_id'),
	        'pecan_mlssid' => $self->o('pecan_mlssid'),
	        'gerp_ce_mlid' => $self->o('gerp_ce_mlid'),
        	'overlaps_method_link_id' => $self->o('overlaps_method_link_id'),
        	'overlaps_method_link_name' => $self->o('overlaps_method_link_name'),
		'overlaps_mlssid' => $self->o('overlaps_mlssid'),
		'min_anchor_size' => 50,
		'pecan_mlssid' => $self->o('pecan_mlssid'),
		'gerp_constrained_element_mlssid' => $self->o('gerp_constrained_element_mlssid'),	
		'min_number_of_org_hits_per_base' => 2,
		'max_frag_diff' => $self->o('max_frag_diff'),
	        'reference_genome_db_id' => $self->o('reference_genome_db_id'),
		'species_set_id' => $self->o('species_set_id'),
		'reference_db' => {
				-user => 'ensro',
				-port => 3306,
				-group => 'core',
				-species => 'homo_sapiens',
	#			-species => 'danio_rerio',
				-host => "ens-livemirror",
				-dbname => 'homo_sapiens_core_67_37',
	#			-dbname => 'danio_rerio_core_62_9b',
				},
	};
	
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";

    return [
# Turn all tables except to InnoDB
	    {	-logic_name	=> 'chunk_reference_dnafrags',
		-module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::ChunkRefDnafrags',
		-parameters	=> {
				    'compara_db' => $self->o('compara_pairwise_db'),
	#			    'method_link_types' => [ 'TRANSLATED_BLAT_NET' ],
				    'method_link_types' => [ 'BLASTZ_NET', 'LASTZ_NET'],
				    'chunk_size' => $self->o('chunk_size'),
				    'genome_db_ids' => $self->o('non_ref_genome_db_ids'),
				   },
		-input_ids 	=> [{}],
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
            {   -logic_name => 'innodbise_table_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='" . 
					$self->o('pipeline_db','-dbname') . "' AND engine='MyISAM' ",
                                'fan_branch_code' => 2,
                               },  
                -input_ids => [{}],
                -flow_into => {
                               2 => [ 'innodbise_table' ],
                              },  
		-wait_for       => [ 'import_entries', 'load_method_link_table' ],
            },  
            {   -logic_name    => 'innodbise_table',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
                -parameters    => {
                                   'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
                                  },  
                -hive_capacity => 1,
            },  
	    {
		-logic_name     => 'set_genome_db_locator',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::SetGenomeDBLocator',
		-parameters     => { 'core_db_urls' => $self->o('core_db_urls') },
		-input_ids => [{}],
		-wait_for       => [ 'innodbise_table' ],
		-flow_into => {
				2 => [ 'mysql:////genome_db?insertion_method=REPLACE' ],
				3 => [ 'mysql:////species_set?insertion_method=INSERT' ],
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
	    { # this sets values in the method_link_species_set and species_set tables
		-logic_name     => 'populate_compara_tables',
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-input_ids => [{}],
		-wait_for       => [ 'set_genome_db_locator', 'load_method_link_table' ],
		-parameters => {
				'sql' => [
						#ml and mlss entries for the overlaps, pecan and gerp
						'REPLACE INTO method_link (method_link_id, type) VALUES('. 
						$self->o('overlaps_method_link_id') . ',"' . $self->o('overlaps_method_link_name')  . '")',
						'REPLACE INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id) VALUES('.
						$self->o('overlaps_mlssid') . ',' . $self->o('overlaps_method_link_id') . ',' . $self->o('species_set_id') . ')',	
						'REPLACE INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id) VALUES('.
						$self->o('pecan_mlssid') . ',' . $self->o('pecan_method_link_id') . ',' . $self->o('species_set_id') . ')',
						'REPLACE INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id) VALUES('.
						$self->o('gerp_constrained_element_mlssid') . ',' . $self->o('gerp_ce_mlid') . ',' . $self->o('species_set_id') . ')',
				],
		},
	    },
	    {
		-logic_name => 'load_species_tree',
		-module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
			'inputcmd'        => 'cat ' . $self->o('species_tree_file') . ' | tr \'[A-Z]\' \'[a-z]\'',
            'column_names'    => [ 'the_tree_itself' ],
			'input_id'        => { 'method_link_species_set_id' => $self->o('pecan_mlssid'), 'tag' => 'species_tree', 'value' => '#the_tree_itself#' },
			'fan_branch_code' => 2,
		},
		-input_ids      => [{}],
		-wait_for       => [ 'populate_compara_tables' ],
		-flow_into => {
				2 => [ 'mysql:////method_link_species_set_tag' ],
		},
	   },
	   {
		-logic_name	=> 'find_pairwise_overlaps',
		-module		=> 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindPairwiseOverlaps',
		-wait_for      => [ 'populate_compara_tables' ],
		-parameters     => { 'overlaps_mlssid' => $self->o('overlaps_mlssid'), },
		-flow_into	=> {
					2 => [ 'pecan' ],
					3 => [ 'mysql:////dnafrag_region?insertion_method=INSERT_IGNORE' ],
				   },
		-hive_capacity => 100,
	   },
	   {
		-logic_name    => 'pecan',
		-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
		-wait_for      => [ 'populate_compara_tables', 'load_species_tree', ],
		-parameters    => { 'mlss_id' => $self->o('pecan_mlssid'), 
				    'max_block_size' => $self->o('pecan_block_size'),
				    'java_options' => '-server -Xmx1000M',},
		-flow_into      => {
					-1 => [ 'pecan_high_mem' ],
					1 => [ 'gerp_constrained_element' ],
				   },
		-hive_capacity => 50,
		-failed_job_tolerance => 10, 
		-max_retry_count => 1,
   	   },
           {    -logic_name => 'pecan_high_mem',
                -parameters => {
			'mlss_id' => $self->o('pecan_mlssid'),
                        'max_block_size' => $self->o('pecan_block_size'),
                        java_options => '-server -Xmx6000M',
                },  
                -module => 'Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan',
                -hive_capacity => 10, 
                -can_be_empty => 1,
                -rc_name => 'mem7500',
		-failed_job_tolerance => 100,
		-max_retry_count => 1,
           },  
	   {
		-logic_name    => 'gerp_constrained_element',
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
		-parameters    => { 'window_sizes' => '[1,10,100,500]', 'gerp_exe_dir' => $self->o('gerp_exe_dir'), 
				    'program_version' => $self->o('gerp_program_version'), 'mlss_id' => $self->o('pecan_mlssid'), },
		-hive_capacity => 100,
		-batch_size    => 5,
	   },
	   { 
		-logic_name     => 'transfer_ce_data_to_anchor_align',
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-input_ids => [{'min_ce_length'=>$self->o('min_ce_length'),}],
		-wait_for       => [ 'gerp_constrained_element' ],
		-parameters => {
				'sql' => [
					'INSERT INTO anchor_align (method_link_species_set_id, anchor_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand) '.
					'SELECT method_link_species_set_id, constrained_element_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM '. 
					'constrained_element WHERE (dnafrag_end - dnafrag_start + 1) >= '. $self->o('min_ce_length') .' ORDER BY constrained_element_id',
				],
		},
	    },
            {   -logic_name => 'trim_anchor_align_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids => [{}],
                -parameters => {
                                'inputquery'      => "SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align",
                                'fan_branch_code' => 2,
                               },  
                -flow_into => {
                               2 => [ 'trim_anchor_align' ],
                              },  
		-wait_for  => [ 'transfer_ce_data_to_anchor_align' ],
            },  
	    {   -logic_name => 'trim_anchor_align',			
		-module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
		-parameters => {
				'input_method_link_species_set_id' => $self->o('gerp_constrained_element_mlssid'),
				'output_method_link_species_set_id' => $self->o('overlaps_mlssid'),
			},
		-failed_job_tolerance => 10,
		-hive_capacity => 200,
		-batch_size    => 10,
		
	    },
	    {   -logic_name => 'load_anchor_sequence_factory',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids => [{}],
		-parameters => {
				'inputquery'  => 'SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align WHERE method_link_species_set_id = ' . $self->o('overlaps_mlssid'),
				'fan_branch_code' => 2,
			},
		-flow_into => {
			2 => [ 'load_anchor_sequence' ],
			}, 
		-wait_for  => [ 'trim_anchor_align' ],
	   },	
	   {   -logic_name => 'load_anchor_sequence',
	       -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::LoadAnchorSequence',
	       -parameters => {
				'input_method_link_species_set_id' => $self->o('overlaps_mlssid'),
				'max_anchor_seq_len' => $self->o('max_anchor_seq_len'),
				'min_anchor_seq_len' => $self->o('min_ce_length'),
			},
		-batch_size    => 10,
		-hive_capacity => 100,
	   },
    ];
}	


1;
