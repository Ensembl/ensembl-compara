
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

	   # version number of core dbs to access for sequence
	'core_db_version' => 68,

	   # parameters that are likely to change from execution to another:
	'release'               => '69',
	'rel_suffix'            => '',    # an empty string by default, a letter otherwise
	   # dependent parameters:
	'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
	'species_tag' 		=> '13way',

	   # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-host   => 'compara4',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $self->o('ENV', 'USER').'_compara_epo_'.$self->o('species_tag')."_".$self->o('rel_with_suffix'),
   	},
	 # ancestral seqs db
	'ancestor_db' => {
		-user => 'ensadmin',
		-host => 'compara4',
		-port => 3306,
		-pass => $self->o('password'),
		-name => 'ancestral_sequences',
		-dbname => $self->o('ENV', 'USER').'_ancestral_sequences_core_'.$self->o('rel_with_suffix'),
	},
	  # database containing the mapped anchors
	'compara_mapped_anchor_db' => {
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara4',
		-dbname => 'sf5_13_mammal_anchor_mappings69',
	},
	 # master db
	'compara_master' => {
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara1',
		-dbname => 'sf5_ensembl_compara_master',
	},
	'main_core_dbs' => [
		{
			-user => 'ensro',
			-port => 3306,
			-host => 'ens-livemirror',
			-dbname => '',
			-db_version => $self->o('core_db_version') || $self->o('release'),
		},
	
#		{
#			-user => 'ensro',
#			-port => 3306,
#			-host => 'ens-staging2',
#			-dbname => '',
#			-db_version => $self->o('core_db_version') || $self->o('release'),
#		},
	],
	# dbs thay may be on genebuild dbs etc
	other_core_dbs => [
#		{
#			-user => 'ensro',
#			-port => 3306,
#			-dbname => 'cgg_dog_ref',
#			-species => "canis_familiaris",
#			-host => 'genebuild1',
#		},
#		{
#			-user => 'ensro',
#			-port => 3306,
#			-dbname => 'mus_musculus_core_68_38',
#			-species => "mus_musculus",
#			-host => 'ens-staging2',
#		},
	],
	  # mlssid of mappings to use
	'mapping_mlssid' => 11000,
	  # mlssid of ortheus alignments
	'ortheus_mlssid' => 609,
	  # species tree file
	'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
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
	%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
	'default' => {'LSF' => '-C0 -M2500000 -R"select[mem>2500] rusage[mem=2500]"' }, 
	'mem3500' => {'LSF' => '-C0 -M3500000 -R"select[mem>3500] rusage[mem=3500]"' },
	'mem7500' => {'LSF' => '-C0 -M7500000 -R"select[mem>7500] rusage[mem=7500]"' },
	'mem10500' =>{'LSF' => '-C0 -M10500000 -R"select[mem>10500] rusage[mem=10500]"' },
	'hugemem' => {'LSF' => '-q hugemem -C0 -M30000000 -R"select[mem>30000] rusage[mem=30000]"' },
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},

		'compara_mapped_anchor_db' => $self->o('compara_mapped_anchor_db'),
		'compara_master' => $self->o('compara_master'),
		'main_core_dbs' => $self->o('main_core_dbs'),
		'other_core_dbs' => $self->o('other_core_dbs'),
		'mapping_mlssid' => $self->o('mapping_mlssid'),
		'ortheus_mlssid' => $self->o('ortheus_mlssid'),
		'mapping_file' => $self->o('mapping_file'),
		'enredo_output_file' => $self->o('enredo_output_file'),
		'ancestor_db' => $self->o('ancestor_db'),
		'core_cvs_sql_schema' => $self->o('core_cvs_sql_schema'),
		'core_db_version' => $self->o('core_db_version'),
		'bl2seq' => $self->o('bl2seq'),
		'addMT' => $self->o('addMT'),
		'species_tree_file' => $self->o('species_tree_file'),
	};
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";

return [
		# dump mapping info from mapping db
	    {  -logic_name => 'dump_mappings_to_file',
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
		# populate the genome_db, species_set, method_link, method_link_species_set and dnafrag tables
		# create an ancestral core db
		# parse the enredo file - add the info to the dnafrag_region and synteny_region tables		
	    {  -logic_name => 'load_genomeDB_dnafrag_dnafragRegion',
	       -module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::ParseEnredo',
	       -parameters => {
				compara_master => $self->o('compara_master'),
				other_core_dbs => $self->o('other_core_dbs'),
				ortheus_mlssid => $self->o('ortheus_mlssid'),
				ancestor_db => $self->o('ancestor_db'),
				main_core_dbs => $self->o('main_core_dbs'),
			      },
		-flow_into => {
				1 => [ 'find_dnafrag_region_strand', 'set_internal_ids', 'make_species_tree' ],
				2 => [ 'Ortheus' ],
			},
	    },
	
		# add a newick species tree to the method_link_species_set_tag table
	   {   -logic_name    => 'make_species_tree',
               -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
               -parameters    => { 
                                   'mlss_id' => $self->o('ortheus_mlssid'),
				   'blength_tree_file' => $self->o('species_tree_file'),
				   'newick_format' => 'simple',
                                  },  
               -hive_capacity => -1,   # to allow for parallelization
               -flow_into => {
                         4 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
                         },  
            },
	  	# find the most likely strand orientation for genomic regions which enredo was unable to determine orientation (set to '0' in the enredo output file 
	    {	-logic_name => 'find_dnafrag_region_strand',
		-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindStrand',
		-parameters => {
				bl2seq => $self->o('bl2seq'),
				bl2seq_file => $self->o('bl2seq_file'),
			       },
		-hive_capacity => 10,
		-flow_into => {
				-1 => [ 'find_dnafrag_region_strand_more_mem' ],
			},
       	   },
	
	   {
		-logic_name => 'find_dnafrag_region_strand_more_mem',
		-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindStrand',
		-parameters => {
				bl2seq => $self->o('bl2seq'),
				bl2seq_file => $self->o('bl2seq_file'),
			       },
		-can_be_empty => 1,
		-rc_name => 'mem3500',
	   },

	   {	-logic_name => 'set_internal_ids',
		-module => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
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
		# run ortheus
	   {	-logic_name => 'Ortheus',
		-parameters => {
				max_block_size=>1000000,
				java_options=>'-server -Xmx1000M',
			},
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
		-hive_capacity => 100,
		-flow_into => {
			-1 => [ 'Ortheus_high_mem' ],
		},
		-wait_for => [ 'set_internal_ids', 'find_dnafrag_region_strand', 'find_dnafrag_region_strand_more_mem', 'make_species_tree' ],
	   },
		
		# increase compute memory and java memory if default settings fail 
	   {	-logic_name => 'Ortheus_high_mem',
		-parameters => {
			max_block_size=>1000000,
			java_options=>'-server -Xmx6000M',
		},
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
		-hive_capacity => 10,
		-flow_into => {
			-1 => [ 'Ortheus_huge_mem' ],
		},
		-rc_name => 'mem14000',
	   },

		# increase compute memory and java memory if previous settings fail 
	   {	-logic_name => 'Ortheus_huge_mem',
		-parameters => {
			max_block_size=>1000000,
			java_options=>'-server -Xmx10000M',
		},
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
		-hive_capacity => 10,
		-can_be_empty => 1,
		-rc_name => 'hugemem',
	   },

	   {  -logic_name => 'update_max_alignment_length',
             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
	     -input_ids => [{}],
	     -parameters => {
				'method_link_species_set_id' => $self->o('ortheus_mlssid'),
		},
	     -wait_for => [ 'Ortheus', 'Ortheus_high_mem' ],
            },  
		# set up jobs for updating left_index and right_index values in genomic_align_tree table
	    {	-logic_name => 'create_neighbour_nodes_jobs_alignment',
		-input_ids => [{}],
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
	
       	    { 	-logic_name => 'set_neighbour_nodes',
		-module => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
		-parameters => {
				'method_link_species_set_id' => $self->o('ortheus_mlssid'),
			},
		-batch_size    => 20,
	    },
	
     ];
}	

1;
