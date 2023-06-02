=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors

=head1 DESCRIPTION  

Partial PipeConfig file that contains the analyses to align the
anchors to a set of target genomes using exonerate.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS


sub pipeline_analyses_epo_anchor_mapping {
	my ($self) = @_;

        return [

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

            {   -logic_name => 'copy_table_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                    'db_conn'      => '#master_db#',
                    'inputlist'    => [ 'method_link', 'ncbi_taxa_name', 'ncbi_taxa_node' ],
                    'column_names' => [ 'table' ],
                },
                -flow_into => {
                    '2->A' => { 'copy_table' => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' } },
                    'A->1' => [ 'offset_tables' ],
                },
            },

            {   -logic_name    => 'copy_table',
                -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters    => {
                    'mode'          => 'topup',
                    'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                },
            },


# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        # CreateReuseSpeciesSets/PrepareSpeciesSetsMLSS may want to create new
        # entries. We need to make sure they don't collide with the master database
        {   -logic_name => 'offset_tables',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql'   => [
                    'ALTER TABLE species_set_header      AUTO_INCREMENT=10000001',
                    'ALTER TABLE method_link_species_set AUTO_INCREMENT=10000001',
                ],
            },
            -flow_into      => [ 'load_genomedb_factory' ],
        },

            {   -logic_name => 'load_genomedb_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -parameters => {
                    'compara_db'            => '#master_db#',   # that's where genome_db_ids come from
                    'extra_parameters'      => [ 'locator' ],
                },
                -flow_into => {
                    '2->A' => { 'load_genomedb' => { 'master_dbID' => '#genome_db_id#', 'locator' => '#locator#' }, },
                    'A->1' => [ 'create_mlss_ss' ],
                },
            },

            {   -logic_name => 'load_genomedb',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
		-hive_capacity => $self->o('low_capacity'),
                -flow_into => [ 'copy_dnafrags_from_master' ],
            },

            {   -logic_name => 'copy_dnafrags_from_master',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
                -parameters => {
                    'src_db_conn'   => '#master_db#',
                    'table'         => 'dnafrag',
                    'where'         => 'genome_db_id = #genome_db_id# AND is_reference = 1',
                    'mode'          => 'insertignore',
                },
		-hive_capacity => $self->o('low_capacity'),
                -flow_into => [ 'check_reusability' ],
            },

            {   -logic_name => 'check_reusability',
                -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::CheckDnaFragReusability',
                -parameters => {
                    'do_not_reuse_list' => $self->o('do_not_reuse_list'),
                },
                -flow_into => {
                    2 => '?accu_name=reused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
                    3 => '?accu_name=nonreused_gdb_ids&accu_address=[]&accu_input_variable=genome_db_id',
                },
		-hive_capacity => $self->o('low_capacity'),
            },

            {   -logic_name => 'create_mlss_ss',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS',
                -parameters => {
                    'whole_method_links'    => [ 'EPO' ],
                },
                -flow_into => [ 'reuse_anchor_align_factory' ],
            },

            {   -logic_name     => 'reuse_anchor_align_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -parameters => {
                    'species_set_id'    => '#reuse_ss_id#',
                },
                -flow_into => {
                    '2->A' => [ 'reuse_anchor_align' ],
                    'A->1' => [ 'map_anchor_align_genome_factory' ],
                },
            },

            # Copy all the untrimmed anchor_aligns
            {   -logic_name => 'reuse_anchor_align',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin',
                -parameters => {
                    'db_conn'    => '#reuse_db#',
                    'table'      => 'anchor_align',
                    'inputquery' => 'SELECT anchor_align_id, #mlss_id#, anchor_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, score, num_of_organisms, num_of_sequences, evalue, untrimmed_anchor_align_id, 0 FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE genome_db_id = #genome_db_id# AND untrimmed_anchor_align_id IS NULL',
                },
		-hive_capacity => $self->o('low_capacity'),
            },

            {   -logic_name     => 'map_anchor_align_genome_factory',
                -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
                -parameters => {
                    'species_set_id'    => '#nonreuse_ss_id#',
                },
                -flow_into => {
                    '2->A'  => [ 'map_anchors_factory' ],
                    'A->1'  => [ 'remove_overlaps' ],
                },
            },

	    {	-logic_name     => 'map_anchors_factory',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchorsFactory',
		-parameters     => {
			'anchor_batch_size' => $self->o('anchor_batch_size'),
		},
		-flow_into => {
                        '2->A' => { 'map_anchors' => INPUT_PLUS() },
                        'A->1' => [ 'missing_anchors_factory' ],
		},
		-rc_name => '4Gb_job',
		-hive_capacity => $self->o('low_capacity'),
	    },

	    {	-logic_name     => 'map_anchors',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors',
		-parameters => {
			'mapping_exe' => $self->o('exonerate_exe'),
	                'mapping_params' => $self->o('mapping_params'),
                        'server_exe' => $self->o('server_exe'),
                        'with_server' => 1,
		},
                -flow_into => {
                    2 => { 'map_anchors' => INPUT_PLUS() },
                    -1 => 'map_anchors_himem',
                },
                -batch_size => $self->o('map_anchors_batch_size'),
                -hive_capacity => $self->o('map_anchors_capacity'),
                -rc_name => '8Gb_job',
                -priority => -10,
		-max_retry_count => 1,
	    },

	    {	-logic_name     => 'map_anchors_himem',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors',
		-parameters => {
			'mapping_exe' => $self->o('exonerate_exe'),
	                'mapping_params' => $self->o('mapping_params'),
                        'server_exe' => $self->o('server_exe'),
                        'with_server' => 1,
		},
                -flow_into => {
                    2 => { 'map_anchors_himem' => INPUT_PLUS() },
                },
                -batch_size => $self->o('map_anchors_batch_size'),
                -hive_capacity => $self->o('map_anchors_capacity'),
                -rc_name => '16Gb_job',
		-max_retry_count => 1,
	    },

            {   -logic_name     => 'map_anchors_no_server',
                -module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors',
                -parameters => {
                    'mapping_exe' => $self->o('exonerate_exe'),
                    'mapping_params' => $self->o('mapping_params'),
                },
                -flow_into => {
                    -1 => 'map_anchors_no_server_himem',
                },
                -batch_size => $self->o('map_anchors_batch_size'),
                -hive_capacity => $self->o('map_anchors_capacity'),
                -rc_name => '8Gb_job',
                -priority => -10,
                -max_retry_count => 1,
            },

            {   -logic_name     => 'map_anchors_no_server_himem',
                -module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors',
                -parameters => {
                    'mapping_exe' => $self->o('exonerate_exe'),
                    'mapping_params' => $self->o('mapping_params'),
                },
                -batch_size => $self->o('map_anchors_batch_size'),
                -hive_capacity => $self->o('map_anchors_capacity'),
                -rc_name => '32Gb_job',
                -max_retry_count => 1,
            },

            {   -logic_name     => 'missing_anchors_factory',
                -module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::MissingAnchorsFactory',
                -parameters => {
                    'anchor_batch_size' => 100,
                },
                -flow_into => {
                    2 => { 'map_anchors_no_server' => INPUT_PLUS(), },
                },
            },

	    {	-logic_name     => 'remove_overlaps',
		-module         => 'Bio::EnsEMBL::Compara::Production::EPOanchors::RemoveAnchorOverlaps',
		-rc_name => '4Gb_job',
		-flow_into => {
			1 => [ 'trim_anchor_align_factory' ],
		},
	    },

            {   -logic_name => 'trim_anchor_align_factory',
                -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
                -parameters => {
                                'inputquery'      => "SELECT DISTINCT(anchor_id) AS anchor_id FROM anchor_align WHERE untrimmed_anchor_align_id IS NULL AND is_overlapping = 0",
                               },  
                -flow_into => {
                               2 => { 'trim_anchor_align' => INPUT_PLUS() },
                              },  
		-rc_name => '4Gb_job',
            },  

	    {   -logic_name => 'trim_anchor_align',			
		-module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
		-parameters => {
                                'method_link_species_set_id' => '#mlss_id#',
                                'ortheus_c_exe' => $self->o('ortheus_c_exe'),
			},
                -flow_into => {
                    -1 => 'trim_anchor_align_himem',
                },
                -rc_name   => '2Gb_job',
		-hive_capacity => $self->o('trim_anchor_align_capacity'),
		-batch_size    => $self->o('trim_anchor_align_batch_size'),
	    },

	    {   -logic_name => 'trim_anchor_align_himem',
		-module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
		-parameters => {
                                'method_link_species_set_id' => '#mlss_id#',
                                'ortheus_c_exe' => $self->o('ortheus_c_exe'),
			},
        -flow_into => { -1 => 'ignore_huge_trim_anchor_align' },
		-hive_capacity => $self->o('trim_anchor_align_capacity'),
		-batch_size    => $self->o('trim_anchor_align_batch_size'),
        -rc_name => '8Gb_job',
	    },

        # some jobs just will not run, no matter how much memory is allocated - ignore them
        {   -logic_name => 'ignore_huge_trim_anchor_align', 
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -meadow_type=> 'LOCAL',
        },
    ];
}	


1;
