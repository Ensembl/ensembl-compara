# Configuration file for mapping (using exonerate at the moment) anchors 

package Bio::EnsEMBL::Compara::PipeConfig::MapAnchors;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
	%{$self->SUPER::default_options},
        'pipeline_name' => 'compara_MapAnchors',
	'ensembl_cvs_root_dir' => $ENV{'ENSEMBL_CVS_ROOT_DIR'},
	   # parameters that are likely to change from execution to another:
	'release'               => '69',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
	'password'              => $ENV{'ENSADMIN_PSW'},
	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara3',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $ENV{'USER'}.'_anchor_mappings'.$self->o('rel_with_suffix'),
   	},
	  # database containing the anchors for mapping
	'compara_anchor_db' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'compara3',
		-pass => '',
		-group => 'compara',
		-dbname => 'sf5_new_mammal_anchors69',
	},
	  # genome_db_id(s) to which to map the anchors
	'genome_db_ids_of_species_to_map' => '3,31,60,61,90,108,117,122,123,125,132,135,134',
	  # location of species core dbs to map to
	'core_db_urls' => [ 'mysql://ensro@ens-staging1:3306/68', 'mysql://ensro@ens-staging2:3306/68' ],
	'mapping_exe' => "/software/ensembl/compara/exonerate/exonerate",
	'species_set_id' => 10000,
	'anchors_mlss_id' => 10000,
	'mapping_method_link_id' => 10000,
	'mapping_method_link_name' => 'MAP_ANCHORS',
	'mapping_mlssid' => 10000,
	'trimmed_mapping_mlssid' => 11000,
	 # place to dump the genome sequences
	'seq_dump_loc' => '/data/blastdb/Ensembl/' . 'compara_genomes_' . $self->o('release'),
	 # dont overwrite genome_db row if locator field is filled 
	'dont_change_if_locator' => 1, 
	 # dont dump the MT sequence for mapping
	'dont_dump_MT' => 1,
	 # batch size of grouped anchors to map
	'anchor_batch_size' => 10,
	 # max number of sequences to allow in an anchor
	'anc_seq_count_cut_off' => 10,
	 # db to transfer the raw mappings to 
	'compara_mapping_db' => {
		-user => 'ensadmin',
		-host   => 'compara3',
		-port   => 3306,
		-pass   => $self->o('password'),
	},
	'compara_master' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'compara1',
		-pass => '',
		-dbname => 'sf5_ensembl_compara_master',
	},
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
         0 => { -desc => 'mem2500',  'LSF' => '-C0 -M2500000 -R"select[mem>2500] rusage[mem=2500]"' },
         1 => { -desc => 'mem3500',  'LSF' => '-C0 -M3500000 -R"select[mem>3500] rusage[mem=3500]"' },
         2 => { -desc => 'mem7500',  'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },  
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'anchors_mlss_id' => $self->o('anchors_mlss_id'),
		'species_set_id' => $self->o('species_set_id'),
		'mapping_method_link_id' => $self->o('mapping_method_link_id'),
        	'mapping_method_link_name' => $self->o('mapping_method_link_name'),
        	'mapping_mlssid' => $self->o('mapping_mlssid'),
		'trimmed_mapping_mlssid' => $self->o('trimmed_mapping_mlssid'),
		'seq_dump_loc' => $self->o('seq_dump_loc'),
		'compara_anchor_db' => $self->o('compara_anchor_db'),
	};
	
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";

    return [
	# load in the genome_db entries from the anchors db and then from the compara_master
	    {   -logic_name     => 'load_genome_db_from_anchor_db',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
		-input_ids => [{}],
		-parameters => {
			'src_db_conn'   => $self->o('compara_anchor_db'),
			'table'         => 'genome_db',
		},
	    },
	    {   -logic_name => 'import_genome_dbs',
	        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids => [{}],
    	        -parameters => {
	            'db_conn'   => $self->o('compara_master'),
	            'inputquery'    => 'SELECT * FROM genome_db WHERE genome_db_id IN (' . $self->o('genome_db_ids_of_species_to_map') . ')',
		    'fan_branch_code' => 2,
	        },
		-wait_for => [ 'load_genome_db_from_anchor_db' ],
		-flow_into => {
			2 => [ 'mysql:////genome_db?insertion_method=REPLACE' ],
		},
	    },
	    {    -logic_name     => 'load_dnafrag_from_anchor_db',
		 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
		 -input_ids => [{}],
		 -parameters => {
			'src_db_conn'   => $self->o('compara_anchor_db'),
			'table'         => 'dnafrag',
		},
	    },
	    {   -logic_name => 'import_dnafrags',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids => [{}],
		-parameters => {
			'db_conn'   => $self->o('compara_master'),
			'inputquery'    => 'SELECT * FROM dnafrag WHERE genome_db_id IN (' . $self->o('genome_db_ids_of_species_to_map') . ')',
			'fan_branch_code' => 2,
		},
	        -wait_for => [ 'load_dnafrag_from_anchor_db' ],
	        -flow_into => {
			2 => [ 'mysql:////dnafrag?insertion_method=REPLACE' ],
	        },
	    },
	    {
		-logic_name     => 'set_genome_db_locator',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::SetGenomeDBLocator',
		-parameters     => { 'core_db_urls' => $self->o('core_db_urls') },
		-input_ids => [{dont_change_if_locator => $self->o('dont_change_if_locator'),}],
		-wait_for       => [ 'import_genome_dbs' ],
		-flow_into => {
				2 => [ 'mysql:////genome_db?insertion_method=REPLACE' ],
				3 => [ 'mysql:////species_set?insertion_method=INSERT' ],
		},
	    },
	    {
		-logic_name     => 'set_assembly_default_to_zero',
	   	-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-input_ids => [{}],
		-wait_for       => [ 'set_genome_db_locator' ],
		-parameters => {
				'sql' => [ 
					'UPDATE genome_db SET assembly_default = 0, locator = DEFAULT WHERE genome_db_id NOT IN (' .
					$self->o('genome_db_ids_of_species_to_map') . ')',
				],
		},	
	    },
	    { # this sets values in the method_link_species_set and species_set tables
		-logic_name     => 'populate_compara_tables',
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-input_ids => [{}],
		-wait_for       => [ 'set_assembly_default_to_zero' ],
		-parameters => {
				'sql' => [
					# ml and mlss entries for the overlaps, pecan and gerp
					'REPLACE INTO method_link (method_link_id, type) VALUES('. 
					$self->o('mapping_method_link_id') . ',"' . $self->o('mapping_method_link_name')  . '")',
					'REPLACE INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id) VALUES('.
					$self->o('mapping_mlssid') . ',' . $self->o('mapping_method_link_id') . ',' . $self->o('species_set_id') . ')',	
				],
		},
	    },
	    {   -logic_name     => 'create_dump_dir',
		-input_ids => [{}],
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
		-wait_for  => [ 'populate_compara_tables' ],
		-parameters => {
			'cmd' => 'mkdir -p ' . $self->o('seq_dump_loc'),
			},
	    },
	    {	-logic_name     => 'dump_genome_sequence_factory',
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids  => [{}],
		-parameters => {
			'inputquery'    => 'SELECT genome_db_id, name AS genome_db_name, assembly AS genome_db_assembly FROM genome_db WHERE genome_db_id IN (' 
						. $self->o('genome_db_ids_of_species_to_map') . ')',
			'fan_branch_code' => 2,
		},
		-flow_into => {
			2  => [ 'dump_genome_sequence' ],
		},
		-wait_for  => [ 'create_dump_dir' ],
	    },
	    {	-logic_name     => 'dump_genome_sequence',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence',
		-parameters => {
			'anc_seq_count_cut_off' => $self->o('anc_seq_count_cut_off'),
			'dont_dump_MT' => $self->o('dont_dump_MT'),
			'anchor_batch_size' => $self->o('anchor_batch_size'),
			'fan_branch_code' => 2,
		},
		-flow_into => {
			2 => [ 'map_anchors' ],
		},
		-rc_id => 1,
		-hive_capacity => 10,
	    },
	    {	-logic_name     => 'map_anchors',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors',
		-parameters => {
			'mapping_exe' => $self->o('mapping_exe'),
		},
		-hive_capacity => 200,
		-failed_job_tolerance => 10,
	    },		
	    {	-logic_name     => 'remove_overlaps',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps',
		-rc_id => 2,
		-wait_for  => [ 'map_anchors' ],
		-input_ids  => [{}],
	    },
            {   -logic_name => 'trim_anchor_align_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-input_ids => [{}],
                -parameters => {
                                'inputquery'      => "SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align WHERE anchor_status IS NULL",
                                'fan_branch_code' => 2,
                               },  
                -flow_into => {
                               2 => [ 'trim_anchor_align' ],
                              },  
		-wait_for  => [ 'remove_overlaps' ],
		-rc_id => 2,
            },  
	    {   -logic_name => 'trim_anchor_align',			
		-module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
		-parameters => {
				'input_method_link_species_set_id' => $self->o('mapping_mlssid'),
				'output_method_link_species_set_id' => $self->o('trimmed_mapping_mlssid'),
			},
		-failed_job_tolerance => 10,
		-hive_capacity => 200,
		-batch_size    => 10,
	    },
    ];
}	


1;
