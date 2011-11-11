
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
	'release'               => '66',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),

	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara3',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $self->o('ENV', 'USER').'_compara_epo'.$self->o('rel_with_suffix'),
   	},
	  # database containing the mapped anchors
	'compara_mapped_anchor_db' => {
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara3',
		-dbname => 'sf5_test_anc_map66',
	},
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
	},
	other_core_dbs => {
	},
	
	  # mlssid of mappings to use
	'mapping_mlssid' => 6,
	  # mlssid of ortheus alignments
	'ortheus_mlssid' => 538,
	  # data directories:
	'mapping_file' => $self->o('ENV', 'EPO_DUMP_PATH').'/enredo_friendly.'.$self->o('rel_with_suffix'),
	'enredo_output_file' => $self->o('ENV', 'EPO_DUMP_PATH').'/enredo.out.'.$self->o('rel_with_suffix'),
	  # code directories:
	'enredo_bin_dir' => '/software/ensembl/compara/',
	'enredo_params' => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',
	  	
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

		'compara_mapped_anchor_db' => $self->o('compara_mapped_anchor_db'),
		'compara_master' => $self->o('compara_master'),
		'mapping_mlssid' => $self->o('mapping_mlssid'),
		'ortheus_mlssid' => $self->o('ortheus_mlssid'),
		'mapping_file' => $self->o('mapping_file'),
		'enredo_output_file' => $self->o('enredo_output_file'),
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
				main_core_dbs => $self->o('main_core_dbs'),
				other_core_dbs => $self->o('other_core_dbs'),
				ortheus_mlssid => $self->o('ortheus_mlssid'),
			      },
	  },
	
     ];
}	

1;
