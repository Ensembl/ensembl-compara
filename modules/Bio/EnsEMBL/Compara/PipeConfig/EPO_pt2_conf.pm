=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. You may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. Check all default_options, you will probably need to change the following :
        release
        pipeline_db (-host)
        resource_classes 

	'ensembl_cvs_root_dir' - the path to the compara/hive/ensembl GIT checkouts - set as an environment variable in your shell
        'password' - your mysql password
	'compara_anchor_db' - database containing the anchor sequences (entered in the anchor_sequence table)
	'compara_master' - location of your master db containing relevant info in the genome_db, dnafrag, species_set, method_link* tables
	'core_db_urls' - the servers(s) hosting all of the core (species) dbs
        The dummy values - you should not need to change these unless they clash with pre-existing values associated with the pairwise alignments you are going to use

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf.pm

    #5. Run the "beekeeper.pl ... -sync" and then " -loop" command suggested by init_pipeline.pl

    #6. Fix the code when it crashes
=head1 DESCRIPTION  

    This configuaration file gives defaults for mapping (using exonerate at the moment) anchors to a set of target genomes (dumped text files)

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPO_pt2_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
	%{$self->SUPER::default_options},
        'pipeline_name' => 'compara_MapAnchors',
	   # parameters that are likely to change from execution to another:
	'release'               => '74',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-driver => 'mysql',
		-host   => 'compara3',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $ENV{'USER'}.'_15mammals_epo_anchor_mappings'.$self->o('rel_with_suffix'),
   	},
	  # database containing the anchors for mapping
	'compara_anchor_db' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'compara3',
		-driver => 'mysql',
		-pass => '',
		-group => 'compara',
		-dbname => 'sf5_TEST_gen_anchors_mammals_cat_100',
	},
	  # genome_db_id(s) to which to map the anchors
	'genome_db_ids_of_species_to_map' => '31,60,61,90,108,117,122,123,125,132,134,135,140,146,139',
	  # location of species core dbs to map to
	'core_db_urls' => [ 'mysql://ensro@ensdb-archive.internal.sanger.ac.uk:5304/73','mysql://ensro@compara1:3306/73' ],
	# 'core_db_urls' => [ 'mysql://ensro@ens-staging1:3306/68', 'mysql://ensro@ens-staging2:3306/68' ],
	'mapping_exe' => "/software/ensembl/compara/exonerate/exonerate",
	'species_set_id' => 10000, # dummy value - should not need to change
	'anchors_mlss_id' => 10000, # this should correspond to the mlss_id in the anchor_sequence table of the compara_anchor_db database (from EPO_pt1_conf.pm)
	'mapping_method_link_id' => 10000, # dummy value - should not need to change
	'mapping_method_link_name' => 'MAP_ANCHORS', 
	'mapping_mlssid' => 10000, # dummy value - should not need to change
	'trimmed_mapping_mlssid' => 11000, # dummy value - should not need to change
	 # place to dump the genome sequences
	'seq_dump_loc' => '/data/blastdb/Ensembl/' . 'compara_genomes_test_' . $self->o('release'),
	 # dont overwrite genome_db row if locator field is filled 
	'dont_change_if_locator' => 1, 
	 # dont dump the MT sequence for mapping
	'dont_dump_MT' => 1,
	 # batch size of grouped anchors to map
	'anchor_batch_size' => 10,
	 # max number of sequences to allow in an anchor
	'anc_seq_count_cut_off' => 15,
	 # db to transfer the raw mappings to - unused at the moment 
	'compara_mapping_db' => {
		-user => 'ensadmin',
		-host   => 'compara4',
		-driver => 'mysql',
		-port   => 3306,
		-pass   => $self->o('password'),
	},
	'compara_master' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'compara3',
		-driver => 'mysql',
		-pass => '',
		-dbname => 'sf5_test_74_mammal_master',
	},
     };
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        'mkdir -p '.$self->o('seq_dump_loc'),
           ];  
}

sub resource_classes {
    my ($self) = @_; 
    return {
	%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
#	'default' => {'LSF' => '-C0 -M2500000 -R"select[mem>2500] rusage[mem=2500]"' }, # farm2 lsf syntax
#	'mem3500' => {'LSF' => '-C0 -M3500000 -R"select[mem>3500] rusage[mem=3500]"' },
#	'mem7500' => {'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },
#	'hugemem' => {'LSF' => '-q hugemem -C0 -M30000000 -R"select[mem>30000] rusage[mem=30000]"' },
	'default' => {'LSF' => '-C0 -M2500 -R"select[mem>2500] rusage[mem=2500]"' }, # farm3 lsf syntax
	'mem3500' => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
	'mem7500' => {'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' },
	'mem14000' => {'LSF' => '-C0 -M14000 -R"select[mem>14000] rusage[mem=14000]"' },
	'hugemem' => {'LSF' => '-q hugemem -C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"' },

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
		-parameters => {
			'src_db_conn'   => $self->o('compara_anchor_db'),
			'table'         => 'genome_db',
		},
		-input_ids => [{}],
		-flow_into => {
			1 => [ 'import_genome_dbs' ],
		},
	    },
	    {   -logic_name => 'import_genome_dbs',
	        -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
    	        -parameters => {
	            'db_conn'   => $self->o('compara_master'),
	            'inputquery'    => 'SELECT * FROM genome_db WHERE genome_db_id IN (' . $self->o('genome_db_ids_of_species_to_map') . ')',
		    'fan_branch_code' => 2,
	        },
		-flow_into => {
			2 => [ 'mysql:////genome_db?insertion_method=REPLACE' ],
			1 => [ 'load_dnafrag_from_anchor_db', 'set_genome_db_locator' ],
		},
	    },
	    {    -logic_name     => 'load_dnafrag_from_anchor_db',
		 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
		 -parameters => {
			'src_db_conn'   => $self->o('compara_anchor_db'),
			'table'         => 'dnafrag',
		},
		-flow_into => {
			1 => [ 'import_dnafrags' ],
		},
	    },
	    {   -logic_name => 'import_dnafrags',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
			'db_conn'   => $self->o('compara_master'),
			'inputquery'    => 'SELECT * FROM dnafrag WHERE genome_db_id IN (' . $self->o('genome_db_ids_of_species_to_map') . ')',
			'fan_branch_code' => 2,
		},
	        -flow_into => {
			2 => [ 'mysql:////dnafrag?insertion_method=REPLACE' ],
	        },
	    },
	    {
		-logic_name     => 'set_genome_db_locator',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::SetGenomeDBLocator',
		-parameters     => { 'core_db_urls' => $self->o('core_db_urls'), dont_change_if_locator => $self->o('dont_change_if_locator'), },
		-flow_into => {
				2 => [ 'mysql:////genome_db?insertion_method=REPLACE' ],
				3 => [ 'mysql:////species_set?insertion_method=INSERT' ],
				1 => [ 'set_assembly_default_to_zero' ],
		},
	    },
	    {
		-logic_name     => 'set_assembly_default_to_zero',
	   	-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
				'sql' => [ 
					'UPDATE genome_db SET assembly_default = 0, locator = DEFAULT WHERE genome_db_id NOT IN (' .
					$self->o('genome_db_ids_of_species_to_map') . ')',
				],
		},	
		-flow_into => {
				1 => [ 'populate_compara_tables' ],
		},
	    },

	    { # this sets values in the method_link_species_set and species_set tables
		-logic_name     => 'populate_compara_tables',
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-parameters => {
			'sql' => [
				# ml and mlss entries for the overlaps, pecan and gerp
				'REPLACE INTO method_link (method_link_id, type) VALUES('. 
				$self->o('mapping_method_link_id') . ',"' . $self->o('mapping_method_link_name')  . '")',
				'REPLACE INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id) VALUES('.
				$self->o('mapping_mlssid') . ',' . $self->o('mapping_method_link_id') . ',' . $self->o('species_set_id') . ')',	
			],
		},
		 -flow_into => {
			1 => [ 'dump_genome_sequence_factory' ],
		},
			
	    },

	    {	-logic_name     => 'dump_genome_sequence_factory',
		-module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-parameters => {
			'inputquery'    => 'SELECT genome_db_id, name AS genome_db_name, assembly AS genome_db_assembly FROM genome_db WHERE genome_db_id IN (' 
						. $self->o('genome_db_ids_of_species_to_map') . ')',
			'fan_branch_code' => 2,
		},
		-flow_into => {
			2  => [ 'dump_genome_sequence' ],
		},
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
		-wait_for  => [ 'import_dnafrags' ],
		-rc_name => 'mem7500',
		-hive_capacity => 2,
		-max_retry_count => 3,
	    },

	    {	-logic_name     => 'map_anchors',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors',
		-parameters => {
			'mapping_exe' => $self->o('mapping_exe'),
		},
		-hive_capacity => 200,
		-failed_job_tolerance => 10,
		-max_retry_count => 1,
	    },

	    {	-logic_name     => 'remove_overlaps',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps',
		-rc_name => 'hugemem',
		-wait_for  => [ 'map_anchors' ],
		-input_ids  => [{}],
		-flow_into => {
			1 => [ 'trim_anchor_align_factory' ],
		},
	    },

            {   -logic_name => 'trim_anchor_align_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery'      => "SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align WHERE anchor_status IS NULL",
                                'fan_branch_code' => 2,
                               },  
                -flow_into => {
                               2 => [ 'trim_anchor_align' ],
                              },  
		-rc_name => 'mem3500',
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
		-max_retry_count => 1,
	    },
    ];
}	


1;
