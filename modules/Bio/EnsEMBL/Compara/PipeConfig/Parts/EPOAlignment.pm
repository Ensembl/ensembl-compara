=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment

=head1 DESCRIPTION

This is a partial PipeConfig to for the last part (3rd part) of the EPO pipeline.
This will genereate the multiple sequence alignments (MSA) from a database containing a
set of anchor sequences mapped to a set of target genomes. The pipeline runs Enredo
(which generates a graph of the syntenic regions of the target genomes)
and then runs Ortheus (which runs Pecan for generating the MSA) and infers
ancestral genome sequences. Finally Gerp may be run to generate constrained elements and
conservation scores from the MSA

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;           # Allow this particular config to use conditional dataflow

use Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats;


sub pipeline_analyses_epo_alignment {
    my ($self) = @_;
    
    return [
        @{ core_pipeline_analyses_epo_alignment($self) },
        @{ pipeline_analyses_gerp($self)               },
        @{ pipeline_analyses_healthcheck($self)        },
    ];
}

sub core_pipeline_analyses_epo_alignment {    
	my ($self) = @_;

return 
[

# ------------------------------------- create the ancestral db	
{
 -logic_name => 'drop_ancestral_db',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
 -parameters => {
  'db_conn' => '#ancestral_db#',
  'input_query' => 'DROP DATABASE IF EXISTS',
  },
  -flow_into => { 1 => 'create_ancestral_db' },
},
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
  'input_file' => $self->o('core_schema_sql'),
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
                'INSERT INTO meta (meta_key, meta_value) VALUES ("species.display_name", "'.$self->o('ancestral_sequences_display_name').'")',
            ],
        },
        -flow_into => 'find_ancestral_seq_gdb',
},
# ------------------------------------- dump mapping info from mapping db to file
{
 -logic_name => 'dump_mappings_to_file',
 -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
 -parameters => {
     'output_file'  => '#enredo_mapping_file#',
     'append'       => [ '-N', '-B', '-q' ],
     'input_query'  => q{SELECT aa.anchor_id, gdb.name, df.name, aa.dnafrag_start, aa.dnafrag_end, CASE
  aa.dnafrag_strand WHEN 1 THEN "+" ELSE "-" END, aa.num_of_organisms, aa.score FROM anchor_align aa INNER JOIN
  dnafrag df ON aa.dnafrag_id = df.dnafrag_id INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id WHERE
  aa.method_link_species_set_id = #mlss_id# AND untrimmed_anchor_align_id IS NOT NULL
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
		  'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
		  'ALTER TABLE genomic_align AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
		  'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
		  'ALTER TABLE dnafrag AUTO_INCREMENT=#expr((#mlss_id# * 10**10) + 1)expr#',
		],
        },
},
{
	-logic_name    => 'make_species_tree',
	-module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
	-parameters    => {
			'species_tree_input_file' => $self->o('binary_species_tree'),
	},
        -flow_into     => WHEN( '#run_gerp#' => [ 'set_gerp_neutral_rate' ],
                                ELSE [ 'dump_mappings_to_file' ] ),
        -rc_name       => '500Mb_job',
},


        {
            -logic_name => 'find_ancestral_seq_gdb',
            -module => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'    => '#master_db#',
                'call_list'     => [ 'compara_dba', 'get_GenomeDBAdaptor', ['fetch_by_name_assembly', $self->o('ancestral_sequences_name')] ],
                'column_names2getters'  => { 'master_dbID' => 'dbID' },
            },
            -rc_name   => '500Mb_job',
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
    -rc_name       => '500Mb_job',
},
# ------------------------------------- run enredo
{
	-logic_name => 'run_enredo',
	-module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
	-parameters => {
		'cmd' => $self->o('enredo_exe').' '.$self->o('enredo_params').' #enredo_output_file# #enredo_mapping_file#',
	},
	-rc_name => '8Gb_job',
        -flow_into => [ 'load_dnafrag_region' ],
},

# ------------------------------------- load the synteny blocks from the enredo output into the dnafrag_region and synteny_region tables
{
	-logic_name => 'load_dnafrag_region',
	-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::LoadDnaFragRegion',
	-parameters => {
                'add_non_nuclear_alignments' => $self->o('add_non_nuclear_alignments'),
	},
        -rc_name   => '4Gb_job',
        -flow_into => {
                '2->A' => [ 'find_dnafrag_region_strand' ],
                '3->A' => [ 'ortheus' ],
		'A->1' => [ 'remove_dodgy_ancestral_blocks' ],
	},
},
# find the most likely strand orientation for genomic regions which enredo was unable to determine the
# orientation (when the strand is set to '0' in the enredo output file)  
{   
	-logic_name => 'find_dnafrag_region_strand',
	-module    => 'Bio::EnsEMBL::Compara::Production::EPOanchors::FindDfrStrand',
	-parameters => {
		bl2seq_exe => $self->o('bl2seq_exe'),
        blastn_exe  => $self->o('blastn_exe'),
		bl2seq_file => $self->o('bl2seq_file_stem'),
	},
        -rc_name   => '4Gb_job',
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
		bl2seq_exe => $self->o('bl2seq_exe'),
        blastn_exe  => $self->o('blastn_exe'),
        bl2seq_file => $self->o('bl2seq_file_stem'),
	},
	-rc_name => '4Gb_job',
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
                'pecan_exe_dir'     => $self->o('pecan_exe_dir'),
                'exonerate_exe'     => $self->o('exonerate_exe'),
                'java_exe'          => $self->o('java_exe'),
                'ortheus_bin_dir'   => $self->o('ortheus_bin_dir'),
                'ortheus_lib_dir'   => $self->o('ortheus_lib_dir'),
                'semphy_exe'        => $self->o('semphy_exe'),
	},
	-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
        -rc_name   => '2Gb_job',
	-hive_capacity => 2000,
	-max_retry_count => 3,
	-flow_into => {
                1 => WHEN( '#run_gerp#' => [ 'gerp' ] ),
		-1 => [ 'ortheus_high_mem' ],
	},
},
# increase compute memory and java memory if default settings fail
{
	-logic_name => 'ortheus_high_mem',
	-parameters => {
		max_block_size=>1000000,
		java_options=>'-server -Xmx2500M -Xms2000m',
                'pecan_exe_dir'     => $self->o('pecan_exe_dir'),
                'exonerate_exe'     => $self->o('exonerate_exe'),
                'java_exe'          => $self->o('java_exe'),
                'ortheus_bin_dir'   => $self->o('ortheus_bin_dir'),
                'ortheus_lib_dir'   => $self->o('ortheus_lib_dir'),
                'semphy_exe'        => $self->o('semphy_exe'),
	},
	-module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
	-rc_name => '8Gb_job',
	-max_retry_count => 2,
	-flow_into => { 
                1 => WHEN( '#run_gerp#' => [ 'gerp' ] ),
		-1 => [ 'ortheus_huge_mem' ],
	},
},
{
        -logic_name => 'ortheus_huge_mem',
        -parameters => {
                max_block_size=>1000000,
                java_options=>'-server -Xmx6500M -Xms6000m',
                'pecan_exe_dir'     => $self->o('pecan_exe_dir'),
                'exonerate_exe'     => $self->o('exonerate_exe'),
                'java_exe'          => $self->o('java_exe'),
                'ortheus_bin_dir'   => $self->o('ortheus_bin_dir'),
                'ortheus_lib_dir'   => $self->o('ortheus_lib_dir'),
                'semphy_exe'        => $self->o('semphy_exe'),
        },  
        -module => 'Bio::EnsEMBL::Compara::RunnableDB::Ortheus',
        -rc_name => '32Gb_job',
	-max_retry_count => 1,
	-flow_into => {
                1 => WHEN( '#run_gerp#' => [ 'gerp' ] ),
        },
},

# ---------------------------------------------------[Update the max_align data in meta]--------------------------------------------------
            {  -logic_name => 'remove_dodgy_ancestral_blocks',
               -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::DeleteDodgyAncestralBlocks',
               -flow_into  => [ 'update_max_alignment_length' ],
            },

            {  -logic_name => 'update_max_alignment_length',
               -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
                -parameters => {
                               'method_link_species_set_id' => '#mlss_id#',
                              },  
               -rc_name => '2Gb_job',
               -flow_into => {
                              1 => [ 'create_neighbour_nodes_jobs_alignment' ],
                             },  
            },  

# --------------------------------------[Populate the left and right node_id of the genomic_align_tree table]-----------------------------
            {   -logic_name => 'create_neighbour_nodes_jobs_alignment',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery' => 'SELECT root_id FROM genomic_align_tree WHERE parent_id IS NULL',
                               },  
                -rc_name => '2Gb_job',
                -flow_into => {
                               '2->A' => [ 'set_neighbour_nodes' ],
                               'A->1' => [ 'healthcheck_factory' ],
                              },  
            },  
            {   -logic_name => 'set_neighbour_nodes',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::SetNeighbourNodes',
                -rc_name    => '2Gb_job',
                -batch_size    => 10, 
                -hive_capacity => 20, 
            },
    ];
}

sub pipeline_analyses_gerp {
    my ($self) = @_;
    
    return [
    
        {   -logic_name => 'set_gerp_neutral_rate',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetGerpNeutralRate',
            -flow_into => {
                1 => [ 'dump_mappings_to_file' ],
                2 => [ '?table_name=pipeline_wide_parameters' ],
            },
        },
    
        # ------------------------------------- run gerp - this will populate the constrained_element and conservation_scores tables
        {   -logic_name => 'gerp',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
            -parameters => {
                'window_sizes' => $self->o('gerp_window_sizes'),
                'gerp_exe_dir' => $self->o('gerp_exe_dir'),
            },
            -max_retry_count => 3,
            -hive_capacity   => 50,
            -rc_name         => '2Gb_job',
            -failed_job_tolerance => 1,
            -flow_into => {
                -1 => [ 'gerp_high_mem' ],
            },
        },
        {   -logic_name => 'gerp_high_mem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::Gerp',
            -parameters => {
                'window_sizes' => $self->o('gerp_window_sizes'),
                'gerp_exe_dir' => $self->o('gerp_exe_dir'),
            },
            -hive_capacity   => 10,
            -rc_name => '8Gb_job',
            -failed_job_tolerance => 100,
        },
    ];
}

sub pipeline_analyses_healthcheck {
    my ($self) = @_;
    
    return [
        # -----------------------------------------------------------[Run healthcheck]------------------------------------------------------------
        {   -logic_name => 'healthcheck_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -meadow_type=> 'LOCAL',
            -flow_into => {
                '1->A' => WHEN( '#run_gerp#' => {
                    'conservation_score_healthcheck'  => [
                        {'test' => 'conservation_jobs', 'logic_name'=>'gerp','method_link_type'=>'EPO'},
                        {'test' => 'conservation_scores'},
                    ],
                }),
                'A->1' => WHEN( 'not #skip_multiplealigner_stats#' => [ 'multiplealigner_stats_factory' ],
                          ELSE [ 'end_pipeline' ]),
            },
        },

        {   -logic_name => 'conservation_score_healthcheck',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HealthCheck',
            -rc_name    => '4Gb_job',
        },
        
        {   -logic_name  => 'end_pipeline',
            -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },
        
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::MultipleAlignerStats::pipeline_analyses_multiple_aligner_stats($self) },
    ];
}

1;
