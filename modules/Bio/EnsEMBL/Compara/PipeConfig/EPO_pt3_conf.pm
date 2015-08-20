=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPO_pt3_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
 my ($self) = @_;

 return {
  %{$self->SUPER::default_options},

        # Change this name
        'species_set_name' => '17mammals_reuse',

        # But not this one
        'pipeline_name' => $self->o('species_set_name').'_epo',

        # Where the pipeline lives
        'host'  => 'compara2',

  'mapping_mlssid' => 11000, # method_link_species_set_id of the final (2bp) mapped anchors
  #'epo_mlss_id' => 647, # method_link_species_set_id of the ortheus alignments which will be generated
#  'gerp_ce_mlss_id' => 648,
#  'gerp_cs_mlss_id' => 50295,
  'species_tree_file' => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.39mammals.branch_len.nw',


  'bl2seq' => '/software/ensembl/compara/bl2seq', # location of ncbi bl2seq executable on farm3
  'enredo_bin_dir' => '/software/ensembl/compara/', # location of enredo executable
  'enredo_params' => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 '.
	'--min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',

        # Dump directory
  'dump_dir' => '/lustre/scratch109/ensembl/'.$ENV{'USER'}.'/epo/'.$self->o('species_set_name').'_'.$self->o('rel_with_suffix').'/',
  'enredo_output_file' => $self->o('dump_dir').'enredo_'.$self->o('epo_mlss_id').'.out',
  'bed_dir' => $self->o('dump_dir').'bed_dir',
  'feature_dumps' => $self->o('dump_dir').'feature_dumps',
  'enredo_mapping_file' => $self->o('dump_dir').'enredo_friendly.mlssid_'.$self->o('epo_mlss_id')."_".$self->o('rel_with_suffix'),
  'bl2seq_dump_dir' => $self->o('dump_dir').'bl2seq', # location for dumping sequences to determine strand (for bl2seq)
  'bl2seq_file_stem' => $self->o('bl2seq_dump_dir')."/bl2seq",

  # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
  'addMT' => 1,
  'jar_file' => '/software/ensembl/compara/pecan/pecan_v0.8.jar',
  'gerp_version' => '2.1', #gerp program version
  'gerp_window_sizes'    => '[1,10,100,500]', #gerp window sizes
  'gerp_exe_dir'    => '/software/ensembl/compara/gerp/GERPv2.1', #gerp program
  'skip_multiplealigner_stats' => 0, #skip this module if set to 1
  'dump_features_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/dumps/dump_features.pl",
  'compare_beds_exe' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/compare_beds.pl",

  'ancestral_sequences_name' => 'ancestral_sequences',
  # connection parameters to various databases:
	'ancestral_db' => { # core ancestral db
		-driver => 'mysql',
		-host   => 'compara4',
		-port   => 3306,
		-species => $self->o('ancestral_sequences_name'),
		-user   => 'ensadmin',
		-pass   => $self->o('password'),
		-dbname => $self->o('ENV', 'USER').'_'.$self->o('species_set_name').'_ancestral_core_'.$self->o('rel_with_suffix'),
	},
	# master db
        'compara_master' => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
	# anchor mappings
        'compara_mapped_anchor_db' => 'mysql://ensro@compara3:3306/sf5_17mammals_epo_anchor_mappings77',

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
        'default' => {'LSF' => '-C0 -M2500 -R"select[mem>2500] rusage[mem=2500]"' },
        'mem3500' => {'LSF' => '-C0 -M3500 -R"select[mem>3500] rusage[mem=3500]"' },
        'mem7500' => {'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' },
        'hugemem' => {'LSF' => '-q hugemem -C0 -M30000 -R"select[mem>30000] rusage[mem=30000]"' },
    };  
}

sub pipeline_wide_parameters {
	my $self = shift @_;
	return {
		%{$self->SUPER::pipeline_wide_parameters},
                'ancestral_db' => $self->o('ancestral_db'),
		'enredo_mapping_file' => $self->o('enredo_mapping_file'),
		'compara_master' => $self->o('compara_master'),
		'compara_mapped_anchor_db' => $self->o('compara_mapped_anchor_db'),
 		'mapping_mlssid' => $self->o('mapping_mlssid'),
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

            {   -logic_name => 'copy_table_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                    'db_conn'      => '#compara_mapped_anchor_db#',
                    'inputlist'    => [ 'method_link', 'genome_db', 'species_set', 'species_set_header', 'method_link_species_set', 'anchor_align', 'dnafrag', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                    'column_names' => [ 'table' ],
                },
                -input_ids => [{}],
                -flow_into => {
                    '2->A' => { 'copy_table' => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' } },
                    '1->A' => [ 'create_ancestral_db', 'set_internal_ids' ],
                    'A->1' => [ 'copy_mlss' ],
                },
            },

            {   -logic_name    => 'copy_table',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                    'mode'          => 'topup',
                    'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                },
            },

            {   -logic_name    => 'copy_mlss',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                    'src_db_conn'   => '#compara_master#',
                    'mode'          => 'topup',
                    'table'         => 'method_link_species_set',
                    'where'         => 'method_link_species_set_id = #epo_mlss_id#',
                },
                -flow_into     => [ 'make_species_tree' ],
            },

# ------------------------------------- create the ancestral db	
{
 -logic_name => 'create_ancestral_db',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
 -parameters => {
  'db_conn' => '#ancestral_db#',
  'input_query' => 'CREATE DATABASE',
  },
  -flow_into => { 1 => 'create_tables_in_ancestral_db' },
},
{
 -logic_name => 'create_tables_in_ancestral_db',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
 -parameters => {
  'db_conn' => '#ancestral_db#',
  'input_file' => $self->o('ensembl_cvs_root_dir')."/ensembl/sql/table.sql",
  },
  -flow_into => { 1 => 'store_ancestral_species_name' },
},
{
        -logic_name => 'store_ancestral_species_name',
        -module => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
        -parameters => {
            'db_conn' => '#ancestral_db#',
            'sql'   => [
                'INSERT INTO meta (meta_key, meta_value) VALUES ("species.production_name", "'.$self->o('ancestral_sequences_name').'")',
                ],
        },
        -flow_into => 'find_ancestral_seq_gdb',
},
# ------------------------------------- dump mapping info from mapping db to file
{
 -logic_name => 'dump_mappings_to_file',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
 -parameters => {
     'db_conn'      => '#compara_mapped_anchor_db#',
     'output_file'  => '#enredo_mapping_file#',
     'append'       => [ '-N', '-B' ],
     'input_query'  => q{SELECT aa.anchor_id, gdb.name, df.name, aa.dnafrag_start, aa.dnafrag_end, CASE
  aa.dnafrag_strand WHEN 1 THEN "+" ELSE "-" END, aa.num_of_organisms, aa.score FROM anchor_align aa INNER JOIN
  dnafrag df ON aa.dnafrag_id = df.dnafrag_id INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id WHERE
  aa.method_link_species_set_id = #mapping_mlssid#
  ORDER BY gdb.name, df.name, aa.dnafrag_start},
  },
   -flow_into => [ 'run_enredo' ],
},
# ------ set up the necessary databas tables for loading the enredo output and runnig ortheus and gerp
{  
	-logic_name => 'set_internal_ids',
	-module => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
	-parameters => {
		'sql'   => [
		  'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr((#epo_mlss_id# * 10**10) + 1)expr#',
		  'ALTER TABLE genomic_align AUTO_INCREMENT=#expr((#epo_mlss_id# * 10**10) + 1)expr#',
		  'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr((#epo_mlss_id# * 10**10) + 1)expr#',
		  'ALTER TABLE dnafrag AUTO_INCREMENT=#expr((#epo_mlss_id# * 10**10) + 1)expr#',
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
        -flow_into     => [ 'dump_mappings_to_file' ],
},

        {
            -logic_name => 'find_ancestral_seq_gdb',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'    => '#compara_master#',
                'call_list'     => [ 'compara_dba', 'get_GenomeDBAdaptor', ['fetch_by_name_assembly', $self->o('ancestral_sequences_name')] ],
                'column_names2getters'  => { 'master_dbID' => 'dbID' },
            },
            -flow_into => {
                2 => 'store_ancestral_seq_gdb',
            },
        },
{
    -logic_name    => 'store_ancestral_seq_gdb',
    -module        => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
    -parameters    => {
        'locator'   => '#ancestral_db#',
    },
},
# ------------------------------------- run enredo
{
	-logic_name => 'run_enredo',
	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	-parameters => {
		'cmd' => $self->o('enredo_bin_dir').'enredo '.$self->o('enredo_params').' #enredo_output_file# #enredo_mapping_file#',
	},
	-rc_name => 'mem7500',
        -flow_into => [ 'load_dnafrag_region' ],
},

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
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
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
                              'ensembl_release' => $self->o('ensembl_release'),
                              'output_dir' => $self->o('feature_dumps'),
                              'mlss_id'   => $self->o('epo_mlss_id'),
                             },
              -rc_name => 'mem3500',
              -hive_capacity => 100,
            },


];
}

1;
