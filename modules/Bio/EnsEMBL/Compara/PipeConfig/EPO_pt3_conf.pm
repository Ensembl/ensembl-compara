=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

 Bio::EnsEMBL::Compara::PipeConfig::EPO_pt3_conf

=head1 DESCRIPTION

    The PipeConfig file for the last part (3rd part) of the EPO pipeline. 
    This will genereate the multiple sequence alignments (MSA) from a database containing a
    set of anchor sequences mapped to a set of target genomes. The pipeline runs Enredo 
    (which generates a graph of the syntenic regions of the target genomes) 
    and then runs Ortheus (which runs Pecan for generating the MSA) and infers 
    ancestral genome sequences. Finally Gerp may be run to generate constrained elements and 
    conservation scores from the MSA

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author: compara

=head VERSION

$Revision: 

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPO_pt3_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
 my ($self) = @_;

 return {
  %{$self->SUPER::default_options},

  'pipeline_name' => '4reptiles_EPOpt3pt2',
  'core_db_version' => 74,
  'rel_with_suffix' => 74,
  'mapping_mlssid' => 11000, # method_link_species_set_id of the final (2bp) mapped anchors
  'epo_mlss_id' => 647, # method_link_species_set_id of the ortheus alignments which will be generated
#  'gerp_ce_mlss_id' => 648,
#  'gerp_cs_mlss_id' => 50295,
  'bl2seq' => '/software/ensembl/compara/bl2seq', # location of ncbi bl2seq executable on farm3
  'bl2seq_dump_dir' => $self->o('dump_dir')."BL2SEQ".$self->o('db_suffix').$self->o('rel_with_suffix'), # location for dumping sequences to determine strand (for bl2seq)
  'bl2seq_file_stem' => $self->o('bl2seq_dump_dir')."/bl2seq",
  'enredo_bin_dir' => '/software/ensembl/compara/', # location of enredo executable
  'enredo_params' => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 '.
	'--min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',
  'enredo_output_file_name' => 'enredo_'.$self->o('epo_mlss_id').'.out',
  'enredo_output_file' => $self->o('dump_dir').$self->o('enredo_output_file_name'),
  'db_suffix' => '_epo_4sauropsids_',
  'ancestral_sequences_name' => 'ancestral_sequences',
  'dump_dir' => $self->o('ENV', 'EPO_DUMP_PATH').'epo_'.$self->o('rel_with_suffix')."/dumps".$self->o('db_suffix').$self->o('rel_with_suffix')."/",
  'bed_dir' => $self->o('dump_dir').'bed_dir',
  'feature_dumps' => $self->o('dump_dir').'feature_dumps',
  'enredo_mapping_file_name' => 'enredo_friendly.mlssid_'.$self->o('epo_mlss_id')."_".$self->o('rel_with_suffix'), 
  'enredo_mapping_file' => $self->o('dump_dir').$self->o('enredo_mapping_file_name'),
  'cvs_dir' => $self->o('ENV', 'ENSEMBL_CVS_ROOT_DIR'), 
  'ancestral_db_cmd' => "mysql -u".$self->o('ancestral_db', '-user')." -P".$self->o('ancestral_db', '-port').
	" -h".$self->o('ancestral_db', '-host')." -p".$self->o('ancestral_db', '-pass'),
  'species_tree_file' => $self->o('cvs_dir').'/ensembl-compara/scripts/pipeline/species_tree_blength.nh',
  # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
  'addMT' => 1,
  'jar_file' => '/software/ensembl/compara/pecan/pecan_v0.8.jar',
  'gerp_version' => '2.1', #gerp program version
  'gerp_window_sizes'    => '[1,10,100,500]', #gerp window sizes
  'gerp_exe_dir'    => '/software/ensembl/compara/gerp/GERPv2.1', #gerp program
  # Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
  # accurate (and slow) method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
  'quick' => 1,
  'skip_multiplealigner_stats' => 0, #skip this module if set to 1
  'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
  'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

  # connection parameters to various databases:
	'pipeline_db' => { # the production database itself (will be created)
		-driver => 'mysql',
		-host   => 'compara4',
		-port   => 3306,
                -user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $self->o('ENV', 'USER').$self->o('db_suffix').$self->o('rel_with_suffix'),
   	},
	'ancestral_db' => { # core ancestral db
		-driver => 'mysql',
		-host   => 'compara4',
		-port   => 3306,
		-species => "ancestral_sequences",
		-user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $self->o('ENV', 'USER').$self->o('db_suffix').'ancestral_core_'.$self->o('rel_with_suffix'),
	},
	# master db
	'compara_master' => {
		-driver => 'mysql',
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara1',
		-dbname => 'sf5_ensembl_compara_master',
	#	-dbname => 'sf5_test_74_mammal_master',
#		-dbname => 'kb3_ensembl_compara_71',
	},
	# location of most of the core dbs
	'main_core_dbs' => [
		{
			-driver => 'mysql',
			-user => 'ensro',
			-port => 3306,
			-host => 'ens-staging1',
			-dbname => '',
			-db_version => $self->o('core_db_version'),
		},
		{
			-driver => 'mysql',
			-user => 'ensro',
			-port => 3306,
			-host => 'ens-staging2',
			-dbname => '',
			-db_version => $self->o('core_db_version'),
		},
               
	
	],
	# any additional core dbs
	'additional_core_db_urls' => { 
#		'ovis_aries' => 'mysql://ensro@compara1:3306/ovis_aries_core_73_1',
	},
	# anchor mappings
	'compara_mapped_anchor_db' => {
		-driver => 'mysql',
		-user => 'ensro',
		-port => 3306,
		-pass => '',
		-host => 'compara2',
	#	-dbname => 'sf5_bird_lizard_epo_anchor_mappings74',
		-dbname => 'sf5_bird_lizard_epo_anchor_mappings74',
#		-dbname => 'sf5_13_mammal_anchor_mappings69',
	},

     }; 
}

sub pipeline_create_commands {
    my ($self) = @_; 
    return [
        @{$self->SUPER::pipeline_create_commands}, 
	'mkdir -p '.$self->o('dump_dir'),
	'mkdir -p '.$self->o('bl2seq_dump_dir'),
        'mkdir -p '.$self->o('bed_dir'),
        'mkdir -p '.$self->o('feature_dumps'),
           ];  
}

sub resource_classes {
    my ($self) = @_; 
    return {
	%{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
	'default' => {'LSF' => '-C0 -M2500 -R"select[mem>2500] rusage[mem=2500]"' }, # reset the default   farm3 lsf syntax
	'mem3500' => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' }, # farm3 lsf syntax
	'mem7500' => {'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' }, # farm3 lsf syntax
	'hugemem' => {'LSF' => '-q hugemem -C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"' }, # farm3 lsf syntax
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},
		'enredo_mapping_file' => $self->o('enredo_mapping_file'),
		'compara_master' => $self->o('compara_master'),
		'main_core_dbs' => $self->o('main_core_dbs'),
		'compara_mapped_anchor_db' => $self->o('compara_mapped_anchor_db'),
 		'mapping_mlssid' => $self->o('mapping_mlssid'),
		'ancestral_db' => $self->o('ancestral_db'),
		'additional_core_db_urls' => $self->o('additional_core_db_urls'),
		'epo_mlss_id' => $self->o('epo_mlss_id'),
#		'gerp_ce_mlss_id' => $self->o('gerp_ce_mlss_id'),
#		'gerp_cs_mlss_id' => $self->o('gerp_cs_mlss_id'),
		'enredo_output_file' => $self->o('enredo_output_file'),
	};
}

sub pipeline_analyses {
	my ($self) = @_;
	print "pipeline_analyses\n";

return 
[
# ------------------------------------- create the ancestral db	
{
 -logic_name => 'create_ancestral_db',
 -input_ids  => [{}],
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
 -parameters => {
  'cmd' => $self->o('ancestral_db_cmd')." -e\"CREATE DATABASE ".$self->o('ancestral_db', '-dbname')."\";".
  $self->o('ancestral_db_cmd')." -D".$self->o('ancestral_db', '-dbname')." <".$self->o('cvs_dir')."/ensembl/sql/table.sql",
  },
  -flow_into => { 1 => 'dump_mappings_to_file' },
},
# ------------------------------------- dump mapping info from mapping db to file
{
 -logic_name => 'dump_mappings_to_file',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
 -parameters => {
  'db_conn' => $self->dbconn_2_mysql('compara_mapped_anchor_db', 1),
  'enredo_mapping_file' => $self->o('enredo_mapping_file'),
  'cmd' => "mysql #db_conn# -NB -e \'SELECT aa.anchor_id, gdb.name, df.name, aa.dnafrag_start, aa.dnafrag_end, CASE ".
  "aa.dnafrag_strand WHEN 1 THEN \"+\" ELSE \"-\" END, aa.num_of_organisms, aa.score FROM anchor_align aa INNER JOIN ".
  "dnafrag df ON aa.dnafrag_id = df.dnafrag_id INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id WHERE ".
  "aa.method_link_species_set_id = \'" . $self->o('mapping_mlssid') . 
  "\' ORDER BY gdb.name, df.name, aa.dnafrag_start\' >"."#enredo_mapping_file#",
  },
   -flow_into => {
	'1->A' => [ 'copy_table_factory', 'run_enredo' ],
#       'A->1' => [ 'dump_before_ldr' ],
        'A->1' => [ 'load_dnafrag_region' ],
	},
},
# ------ set up the necessary databas tables for loading the enredo output and runnig ortheus and gerp
{  
 -logic_name => 'copy_table_factory',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
 -parameters => {
  'db_conn' => $self->o('compara_master'),
  'inputlist'    => [ 'genome_db', 'dnafrag', 'method_link', 'method_link_species_set', 'species_set', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
  'column_names' => [ 'table' ],
 },
 -flow_into => {
  '2->A' => [ 'copy_tables' ],
  'A->1' => [ 'delete_from_copied_tables' ],
 },
 -meadow_type    => 'LOCAL',
},
{ 
  -logic_name    => 'copy_tables',
  -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
  -parameters    => {
	'src_db_conn'   => $self->o('compara_master'),
	'dest_db_conn'  => $self->o('pipeline_db'),
	'mode'          => 'overwrite',
	'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
  },
},
{
  -logic_name => 'delete_from_copied_tables',
  -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
  -parameters => {
   'sql' => [
#    'DELETE FROM method_link_species_set WHERE method_link_species_set_id NOT IN ('.$self->o('epo_mlss_id').','.$self->o('gerp_ce_mlss_id').','.$self->o('gerp_cs_mlss_id').')',
    'DELETE FROM method_link_species_set WHERE method_link_species_set_id NOT IN ('.$self->o('epo_mlss_id').')',
    'DELETE ss.* FROM species_set ss LEFT OUTER JOIN method_link_species_set mlss ON ss.species_set_id = mlss.species_set_id WHERE mlss.species_set_id IS NULL',
    'DELETE df.*, gdb.* FROM dnafrag df INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id LEFT OUTER JOIN species_set ss ON gdb.genome_db_id = ss.genome_db_id WHERE ss.genome_db_id IS NULL AND gdb.name <> "'.$self->o('ancestral_sequences_name').'"',
   'DELETE FROM genome_db WHERE ! assembly_default',
   'DELETE df.* FROM dnafrag df INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id WHERE gdb.name = "'.$self->o('ancestral_sequences_name').'"',
   ],
  },
 -flow_into => { 1 => [ 'set_genome_db_locator_factory', 'set_internal_ids' ], },
},
{
	-logic_name => 'set_genome_db_locator_factory',
	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
	-parameters => {
		'inputquery' => 'SELECT name AS species_loc_name FROM genome_db WHERE assembly_default',
	},
	-flow_into => { 2 => 'update_genome_db_locator', 1 => 'make_species_tree', }, 
},
{
	-logic_name => 'update_genome_db_locator',
	-module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator',
	-meadow_type    => 'LOCAL',
		
}, 
{
	-logic_name => 'set_internal_ids',
	-module => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
	-parameters => {
	'epo_mlssid' => $self->o('epo_mlss_id'),
		'sql'   => [
		  'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr(($epo_mlss_id * 10**10) + 1)expr#',
		  'ALTER TABLE genomic_align AUTO_INCREMENT=#expr(($epo_mlss_id * 10**10) + 1)expr#',
		  'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr(($epo_mlss_id * 10**10) + 1)expr#',
		  'ALTER TABLE dnafrag AUTO_INCREMENT=#expr(($epo_mlss_id * 10**10) + 1)expr#',
		],
        },
},
{
	-logic_name    => 'make_species_tree',
	-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
	-parameters    => {
			'mlss_id' => $self->o('epo_mlss_id'),
			'newick_format' => 'simple',
			'blength_tree_file' => $self->o('species_tree_file'),		
	},
#	-flow_into => {
#		4 => { 'mysql:////' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
#	},
},
# ------------------------------------- run enredo
{
	-logic_name => 'run_enredo',
	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	-parameters => {
		'cmd' => $self->o('enredo_bin_dir').'enredo '.$self->o('enredo_params')." ".$self->o('enredo_output_file')." ".$self->o('enredo_mapping_file'),
	},
},

#{   -logic_name => 'dump_before_ldr',
#    -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DatabaseDumper',
#    -parameters => {
#        'output_file'   => '/lustre/scratch109/ensembl/sf5/EPO_DUMPS/epo_rel80/sf5_epo_multi_way_leo_taxa_test_80.mysql',
#    },
#    -flow_into  => {
#	1 => [ 'load_dnafrag_region' ],
#    },
#},

# ------------------------------------- load the synteny blocks from the enredo output into the dnafrag_region and synteny_region tables
{
	-logic_name => 'load_dnafrag_region',
	-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::LoadDnaFragRegion',
	-parameters => {
		'addMT'	=> $self->o('addMT'),
	},
        -flow_into => {
                '2->A' => [ 'find_dnafrag_region_strand' ],
                '3->A' => [ 'ortheus' ],
		'A->1' => [ 'update_max_alignment_length' ],
	},
},
# find the most likely strand orientation for genomic regions which enredo was unable to determine the
# orientation (when the strand is set to '0' in the enredo output file)  
{   
	-logic_name => 'find_dnafrag_region_strand',
	-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindDfrStrand',
	-parameters => {
		bl2seq => $self->o('bl2seq'),
		bl2seq_file => $self->o('bl2seq_file_stem'),
	},
	-hive_capacity => 10,
	-flow_into => { 
		2 => 'ortheus',
		-1 => 'find_dnafrag_region_strand_more_mem',
	},
},

{
	-logic_name => 'find_dnafrag_region_strand_more_mem',
	-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindDfrStrand',
	-parameters => {
		bl2seq => $self->o('bl2seq'),
		bl2seq_file => $self->o('bl2seq_file_stem'),
	},
	-can_be_empty => 1,
	-rc_name => 'mem3500',
	-flow_into => {
		2 => 'ortheus',
	},
},
# ------------------------------------- run ortheus - this will populate the genomic_align* tables and the seq_region and dna tables in the ancestral db
{
	-logic_name => 'ortheus',
	-parameters => {
		max_block_size => 1000000,
		java_options => '-server -Xmx1000M',
		jar_file => $self->o('jar_file'),
		ortheus_mlssid => $self->o('epo_mlss_id'),
	},
	-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
	-failed_job_tolerance => 1,
	-hive_capacity => 50,
	-max_retry_count => 3,
	-flow_into => {
#		1 => [ 'gerp' ],
		-1 => [ 'ortheus_high_mem' ],
	},
},
# increase compute memory and java memory if default settings fail
{
	-logic_name => 'ortheus_high_mem',
	-parameters => {
		max_block_size=>1000000,
		java_options=>'-server -Xmx2500M -Xms2000m',
		jar_file => $self->o('jar_file'),
		ortheus_mlssid => $self->o('epo_mlss_id'),
	},
	-can_be_empty => 1,
	-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
	-rc_name => 'mem7500',
	-max_retry_count => 2,
	-failed_job_tolerance => 1,
	-flow_into => { 
#		1 => [ 'gerp' ], 
		-1 => [ 'ortheus_huge_mem' ],
	},
},
{
        -logic_name => 'ortheus_huge_mem',
        -parameters => {
                max_block_size=>1000000,
                java_options=>'-server -Xmx6500M -Xms6000m',
		jar_file => $self->o('jar_file'),
                ortheus_mlssid => $self->o('epo_mlss_id'),
        },  
        -module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
        -rc_name => 'hugemem',
	-max_retry_count => 1,
	-failed_job_tolerance => 1,
#        -flow_into => { 
#		1 => [ 'gerp' ],
#        },  
},
# ------------------------------------- run gerp - this will populate the constrained_element and conservation_scores tables
#{
#	-logic_name => 'gerp',
#        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
#        -parameters => {
#            'mlss_id' => $self->o('epo_mlss_id'), 
#            'program_version' => $self->o('gerp_version'),
#            'window_sizes' => $self->o('gerp_window_sizes'),
#            'gerp_exe_dir' => $self->o('gerp_exe_dir'),
#	    'do_transactions' => 0,
#        },
#	-max_retry_count => 3,
#        -hive_capacity   => 50,
#	-failed_job_tolerance => 1,
#        -flow_into => { 
#                -1 => [ 'gerp_high_mem' ],
#        },
#},
#{
#	-logic_name => 'gerp_high_mem',
#        -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
#        -parameters => {
#            'mlss_id' => $self->o('epo_mlss_id'), 
#            'program_version' => $self->o('gerp_version'),
#            'window_sizes' => $self->o('gerp_window_sizes'),
#            'gerp_exe_dir' => $self->o('gerp_exe_dir'),
#        },
#        -hive_capacity   => 10,
#	-rc_name => 'mem7500',
#	-failed_job_tolerance => 100,
#},
# ---------------------------------------------------[Update the max_align data in meta]--------------------------------------------------
            {  -logic_name => 'update_max_alignment_length',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
                -parameters => {
                               'quick' => $self->o('quick'),
                               'method_link_species_set_id' => $self->o('epo_mlss_id'),
                              },  
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
                               '2->A' => [ 'set_neighbour_nodes' ],
                               'A->1' => [ 'healthcheck_factory' ],
                              },  
            },  
            {   -logic_name => 'set_neighbour_nodes',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
                -parameters => {
                                'method_link_species_set_id' => $self->o('epo_mlss_id')
                               },  
                -batch_size    => 10, 
                -hive_capacity => 20, 
            },  
# -----------------------------------------------------------[Run healthcheck]------------------------------------------------------------
            {   -logic_name => 'healthcheck_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
                -meadow_type=> 'LOCAL',
                -flow_into => {
                     1 => [ 'stats_factory' ],
                },
#                               '2->A' => {
#                                     'conservation_score_healthcheck'  => [
#                                                                           {'test' => 'conservation_jobs', 'logic_name'=>'gerp','method_link_type'=>'EPO_LOW_COVERAGE'}, 
#                                                                           {'test' => 'conservation_scores','method_link_species_set_id'=>$self->o('gerp_cs_mlss_id')},
#                                                                ],  
#                                    },  
#                               'A->1' => ['stats_factory'],
#                              },  
            },  

#            {   -logic_name => 'conservation_score_healthcheck',
#                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
#            },

            {   -logic_name => 'stats_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
                -parameters => {
                                'call_list'             => [ 'compara_dba', 'get_GenomeDBAdaptor', 'fetch_all'],
                                'column_names2getters'  => { 'genome_db_id' => 'dbID' },

                                'fan_branch_code'       => 2,
                               },
                -flow_into  => {
                                2 => [ 'multiplealigner_stats' ],
                               },
            },

            { -logic_name => 'multiplealigner_stats',
              -module => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats',
              -parameters => {
                              'skip' => $self->o('skip_multiplealigner_stats'),
                              'dump_features' => $self->o('dump_features_exe'),
                              'compare_beds' => $self->o('compare_beds_exe'),
                              'bed_dir' => $self->o('bed_dir'),
                              'ensembl_release' => $self->o('rel_with_suffix'),
                              'output_dir' => $self->o('feature_dumps'),
                              'mlss_id'   => $self->o('epo_mlss_id'),
                             },
              -rc_name => 'mem3500',
              -hive_capacity => 100,
            },


];
}

1;
