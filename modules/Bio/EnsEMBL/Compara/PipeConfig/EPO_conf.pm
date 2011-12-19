
package Bio::EnsEMBL::Compara::PipeConfig::EPO_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');
use Data::Dumper;

sub default_options {
    my ($self) = @_;

    return {
	%{$self->SUPER::default_options},

        'pipeline_name' => 'compara_EPO',

	   # parameters that are likely to change from execution to another:
	'release'               => '65',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
	'species_tag' 		=> 'primates_',

	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara3',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $self->o('ENV', 'USER').'_TEST_compara_epo_'.$self->o('species_tag').$self->o('rel_with_suffix'),
   	},
	 # ancestral seqs db
	'ancestor_db' => {
		-user => 'ensadmin',
		-host => 'compara3',
		-port => 3306,
		-pass => $self->o('password'),
		-name => 'ancestral_sequences',
		-dbname => $self->o('ENV', 'USER').'_TEST_ancestral_sequences_core_'.$self->o('rel_with_suffix'),
	},
	  # database containing the mapped anchors
	'compara_mapped_anchor_db' => {
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara3',
		-dbname => 'sf5_compara64_anc_align',
	},
	 # master db
	'compara_master' => {
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara1',
		-dbname => 'sf5_ensembl_compara_master',
	},
	'main_core_dbs' => {
		-user => 'ensro',
		-port => 3306,
		-host => 'ens-livemirror',
		-dbname => '',
		-db_version => $self->o('release'),
	},
	other_core_dbs => {
	},
	  # mlssid of mappings to use
	'mapping_mlssid' => 6,
	  # mlssid of ortheus alignments
	'ortheus_mlssid' => 548,
	  # species tree file
	'species_tree_file' => '',
	  # data directories:
	'mapping_file' => $self->o('ENV', 'EPO_DUMP_PATH').'/enredo_friendly.'.$self->o('rel_with_suffix'),
	'enredo_output_file' => $self->o('ENV', 'EPO_DUMP_PATH').'/enredo.out.'.$self->o('rel_with_suffix'),
	'bl2seq_file' => $self->o('ENV', 'EPO_DUMP_PATH').'/bl2seq.'.$self->o('rel_with_suffix'),
	  # code directories:
	'enredo_bin_dir' => '/software/ensembl/compara/',
	'bl2seq' => '/software/bin/bl2seq',
	'core_cvs_sql_schema' => $self->o('ENV', 'ENSEMBL_CVS_ROOT_DIR') . '/ensembl/sql/table.sql',
	  # enredo parameters
	'enredo_params' => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',
	  # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
	'addMT' => 1,
     }; 
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands}, 
           ];  
}

sub resource_classes {
    my ($self) = @_; 
    return {
         0 => { -desc => 'default',  'LSF' => '' },
         1 => { -desc => 'mem3500',  'LSF' => '-C0 -M3500000 -R"select[mem>3500] rusage[mem=3500]"' },
         2 => { -desc => 'mem7500',  'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },  
         3 => { -desc => 'mem11400', 'LSF' => '-C0 -M11400000 -R"select[mem>11400] rusage[mem=11400]"' },  
         4 => { -desc => 'mem14000', 'LSF' => '-C0 -M14000000 -R"select[mem>14000] rusage[mem=14000]"' },  
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'compara_mapped_anchor_db' => $self->o('compara_mapped_anchor_db'),
		'compara_master' => $self->o('compara_master'),
		'main_core_dbs' => $self->o('main_core_dbs'),
		'mapping_mlssid' => $self->o('mapping_mlssid'),
		'ortheus_mlssid' => $self->o('ortheus_mlssid'),
		'mapping_file' => $self->o('mapping_file'),
		'enredo_output_file' => $self->o('enredo_output_file'),
		'ancestor_db' => $self->o('ancestor_db'),
		'core_cvs_sql_schema' => $self->o('core_cvs_sql_schema'),
		'bl2seq' => $self->o('bl2seq'),
		'addMT' => $self->o('addMT'),
	};
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";

return [
		# dump mapping info from mapping db
	    {   -logic_name => 'dump_mappings_to_file',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
		-parameters => {
				'db_conn' => $self->dbconn_2_mysql('compara_mapped_anchor_db', 1),
				'mapping_file' => $self->o('mapping_file'),
				'cmd' => "mysql #db_conn# -NB -e \'SELECT aa.anchor_id, gdb.name, df.name, aa.dnafrag_start, aa.dnafrag_end, CASE aa.dnafrag_strand WHEN 1 THEN \"+\" ELSE \"-\" END, aa.num_of_organisms, aa.score FROM anchor_align aa INNER JOIN dnafrag df ON aa.dnafrag_id = df.dnafrag_id INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id WHERE aa.method_link_species_set_id = " . $self->o('mapping_mlssid') . " ORDER BY gdb.name, df.name, aa.dnafrag_start\' >#mapping_file#",
			       },
		-input_ids => [{'enredo_out_file' => $self->o('enredo_output_file')},],
		-flow_into => {
				1 => [ 'run_enredo' ],
			      },
	    },
		# run enredo
	    {	-logic_name => 'run_enredo',
		-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
		-parameters => {
				'cmd' => $self->o('enredo_bin_dir').'enredo '.$self->o('enredo_params').' #enredo_out_file#'.' #mapping_file#', 
				},
		-flow_into => {	
				1 => [ 'load_genomeDB_dnafrag_dnafragRegion' ],
			      },
	   },
	   
	   {   -logic_name => 'load_genomeDB_dnafrag_dnafragRegion',
	       -module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::ParseEnredo',
	       -parameters => {
				compara_master => $self->o('compara_master'),
				other_core_dbs => $self->o('other_core_dbs'),
				ortheus_mlssid => $self->o('ortheus_mlssid'),
				ancestor_db => $self->o('ancestor_db'),
			      },
		-flow_into => {
				1 => [ 'find_dnafrag_region_strand' ],
				2 => [ 'Ortheus' ],
			},
	  },
	
	  {	-logic_name => 'find_dnafrag_region_strand',
		-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindStrand',
		-parameters => {
				bl2seq => $self->o('bl2seq'),
				bl2seq_file => $self->o('bl2seq_file'),
			       },
		-hive_capacity => 10,
		-failed_job_tolerance => 5, # can start ortheus if a few jobs fail 
		-rc_id => 3, # there should not be too many of these jobs, most of which do not require much memory, but a small number  will
	  },

	  {	-logic_name => 'set_internal_ids',
		-module => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
		-input_ids => [{}],
		-wait_for => [ 'load_genomeDB_dnafrag_dnafragRegion' ],
		-parameters => {
				'ortheus_mlssid' => $self->o('ortheus_mlssid'),
				'sql'   => [
						'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr(($ortheus_mlssid * 10**10) + 1)expr#',
						'ALTER TABLE genomic_align AUTO_INCREMENT=#expr(($ortheus_mlssid * 10**10) + 1)expr#',
						'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr(($ortheus_mlssid * 10**10) + 1)expr#',
						'ALTER TABLE dnafrag AUTO_INCREMENT=#expr(($ortheus_mlssid * 10**10) + 1)expr#',
					],
			},
	  },

	  {	-logic_name => 'Ortheus',
		-parameters => {
				max_block_size=>1000000,
				java_options=>'-server -Xmx1000M',
			},
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
		-hive_capacity => 100,
		-flow_into => {
                               1 => [ 'update_max_alignment_length' ],
                     },
		-wait_for => [ 'set_internal_ids', 'find_dnafrag_region_strand' ],
	  },

	  {  -logic_name => 'update_max_alignment_length',
             -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateMaxAlignmentLength',
	     -parameters => {
				'method_link_species_set_id' => $self->o('ortheus_mlssid'),
		},
             -flow_into => {
                              1 => [ 'create_neighbour_nodes_jobs_alignment' ],
                     },  
            },  
	    {	-logic_name => 'create_neighbour_nodes_jobs_alignment',
		-parameters => {
				'inputquery' => 'SELECT root_id FROM genomic_align_tree WHERE parent_id = 0',
				'fan_branch_code' => 1,
				}, 
		-module => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
		-wait_for => [ 'Ortheus' ],
		-flow_into => {
				1 => [ 'set_neighbour_nodes' ],
			},
	},
	
	{	-logic_name => 'set_neighbour_nodes',
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-parameters => {
				'method_link_species_set_id' => $self->o('ortheus_mlssid'),
			},
		-batch_size    => 10,
		-hive_capacity => 15,
	},
	
     ];
}	

1;
