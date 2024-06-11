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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::UpdateMSA_conf

=head1 SYNOPSYS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::UpdateMSA_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -method_type <lowercase_method_type> -species_set_name <species_set_name>

=head1 DESCRIPTION

The PipeConfig file for the pipeline that copies the data from the previous
release MSA and updates it. This update involves:
- Mercator-Pecan: remove the updated species and recompute GERP
- EPO: copy the ancestral core db and update the dna names, remove the updated
  species from the EPO MSA and update the ancestral dnafrag ids, and recompute
  its EPO Extended MSA (GERP included), incorporating the updated species

=cut

package Bio::EnsEMBL::Compara::PipeConfig::UpdateMSA_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  # for WHEN and INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAncestral;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},  # inherit the generic ones

        'pipeline_name' => $self->o('species_set_name') . '_' . $self->o('method_type') . '_update_' . $self->o('rel_with_suffix'),
        'work_dir'      => $self->o('pipeline_dir'),
        'output_dir'    => $self->o('work_dir') . '/feature_dumps/',
        'bed_dir'       => $self->o('work_dir') . '/bed_dir/',

        'master_db'         => 'compara_master',
        'prev_db'           => $self->o('species_set_name') . '_' . $self->o('method_type') . '_prev',
        'reuse_db'          => $self->o('prev_db'),
        'prev_ancestral_db' => 'ancestral_prev',
        # EPOAncestral parameters
        'ancestral_sequences_name'          => 'ancestral_sequences',
        'ancestral_sequences_display_name'  => 'Ancestral sequences',
        # Core ancestral database, created on the same server as the pipeline database
        'ancestral_db'             => {
            -driver  => $self->o('pipeline_db', '-driver'),
            -host    => $self->o('pipeline_db', '-host'),
            -port    => $self->o('pipeline_db', '-port'),
            -user    => $self->o('pipeline_db', '-user'),
            -pass    => $self->o('pipeline_db', '-pass'),
            -species => $self->o('ancestral_sequences_name'),
            -dbname  => $self->o('dbowner') . '_' . $self->o('species_set_name') . '_ancestral_core_' . $self->o('rel_with_suffix'),
        },
        # EpoExtended parameters
        'max_block_size'    => 1000000,  # max size of alignment before splitting
        'pairwise_location' => [ qw(compara_prev lastz_batch_* unidir_lastz) ],  # default location for pairwise alignments (can be a string or an array-ref)
        'lastz_complete'    => 0,  # set to 1 when all relevant LastZs have complete

        # GERP default parameters
        'run_gerp'          => 1,
        'gerp_window_sizes' => [1, 10, 100, 500],

        # Default statistics
        'skip_multiplealigner_stats'    => 0,  # skip this module if set to 1
        'msa_stats_shared_dir' => $self->o('msa_stats_shared_basedir') . '/' . $self->o('species_set_name') . '/' . $self->o('ensembl_release'),

        # Resource requirements
        'gerp_capacity' => 500,
    };
}


sub pipeline_checks_pre_init {
    my ($self) = @_;
    die "The method type has to be in lowercase" if $self->o('method_type') =~ /^(EPO|PECAN)$/;
    die "The method type '" . $self->o('method_type') . "' is not an updatable MSA" if $self->o('method_type') !~ /^(epo|pecan)$/;
}


sub pipeline_create_commands {
    my ($self) = @_;

    return [
        @{$self->SUPER::pipeline_create_commands},  # inherit creation of DB, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'output_dir', 'bed_dir']),
        $self->pipeline_create_commands_rm_mkdir(['msa_stats_shared_dir'], undef, 'do not rm'),
    ];
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},  # inherit anything from the base class

        'master_db'         => $self->o('master_db'),
        'prev_db'           => $self->o('prev_db'),
        'reuse_db'          => $self->o('reuse_db'),
        'ancestral_db'      => $self->o('ancestral_db'),
        'prev_ancestral_db' => $self->o('prev_ancestral_db'),

        'method_type'       => $self->o('method_type'),
        'species_set_name'  => $self->o('species_set_name'),
        'curr_release'      => $self->o('ensembl_release'),

        'genome_dumps_dir'  => $self->o('genome_dumps_dir'),

        'lastz_complete'             => $self->o('lastz_complete'),
        'run_gerp'                   => $self->o('run_gerp'),
        'skip_multiplealigner_stats' => $self->o('skip_multiplealigner_stats'),
    };
}


sub core_pipeline_analyses {
    my $self = shift;

    my %dc_analysis_params = (
        'compara_db' => $self->pipeline_url(),
        'datacheck_names' => [ 'CheckNonMinimisedGATs' ],
        'db_type' => 'compara',
        'registry_file' => undef,
    );

    return [
        {   -logic_name => 'load_mlss_ids',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMLSSids',
            -input_ids  => [{}],
            -parameters => {
                'method_type'      => $self->o('method_type'),
                'species_set_name' => $self->o('species_set_name'),
                'release'          => '#curr_release#',
                'add_prev_mlss'    => 1,
                'add_sister_mlsss' => 1,
                'branch_code'      => 2,
            },
            -flow_into  => {
                '2->A'  => WHEN(
                    '#method_type# eq "epo" && #run_gerp#'  => { 'populate_new_database' => {
                        'mlss_id_list' => [ '#mlss_id#', '#prev_mlss_id#', '#ext_mlss_id#', '#ce_mlss_id#', '#cs_mlss_id#' ],
                    }},
                    '#method_type# eq "epo" && !#run_gerp#' => { 'populate_new_database' => {
                        'mlss_id_list' => [ '#mlss_id#', '#prev_mlss_id#', '#ext_mlss_id#' ],
                    }},
                    ELSE                                       { 'populate_new_database' => {
                        'mlss_id_list' => [ '#mlss_id#', '#prev_mlss_id#', '#ce_mlss_id#', '#cs_mlss_id#' ],
                    }},
                ),
                'A->2'  => [ 'msa_update_factory' ],
            },
        },
        {   -logic_name => 'populate_new_database',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase',
            -parameters => {
                'program'           => $self->o('populate_new_database_exe'),
                'reg_conf'          => $self->o('reg_conf'),
                'old_compara_db'    => '#prev_db#',
                'filter_by_mlss'    => 1,
                'skip_gerp'         => 1,
            },
            -rc_name    => '1Gb_job',
        },
        # Update the MSA-related information in this and the ancestral core databases
        {   -logic_name => 'msa_update_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => WHEN(
                    '#method_type# eq "epo"'    => {
                        'set_mlss_tag'      => INPUT_PLUS(),
                        'set_internal_ids'  => INPUT_PLUS(),
                        'mlss_factory'      => { 'inputlist' => [['#mlss_id#'], ['#ext_mlss_id#']] },
                        'drop_ancestral_db' => { 'mlss_id' => '#mlss_id#', 'prev_mlss_id' => '#prev_mlss_id#' },
                        'copy_anchor_align_factory' => { 'mlss_id' => '#mlss_id#' },
                    },
                    ELSE                           {
                        'set_gerp_mlss_tag' => { 'ext_mlss_id' => '#mlss_id#', 'ce_mlss_id' => '#ce_mlss_id#', 'cs_mlss_id' => '#cs_mlss_id#' },
                        'mlss_factory'      => { 'inputlist' => [['#mlss_id#']] },
                    }
                ),
                'A->1'  => [ 'transfer_msa' ],
            },
        },
        {   -logic_name => 'set_internal_ids',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [
                    'ALTER TABLE genomic_align AUTO_INCREMENT=#expr((#ext_mlss_id# * 10**10) + 1)expr#',
                    'ALTER TABLE genomic_align_block AUTO_INCREMENT=#expr((#ext_mlss_id# * 10**10) + 1)expr#',
                    'ALTER TABLE genomic_align_tree AUTO_INCREMENT=#expr((#ext_mlss_id# * 10**10) + 1)expr#'
                ],
            },
        },
        {   -logic_name => 'mlss_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names'  => [ 'mlss_id' ],
            },
            -flow_into  => {
                2 => [ 'make_species_tree' ],
            },
        },
        {   -logic_name => 'make_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters => {
                'species_tree_input_file' => $self->o('binary_species_tree'),
            },
            -flow_into  => {
                2 => { 'hc_species_tree' => { 'mlss_id' => '#mlss_id#', 'species_tree_root_id' => '#species_tree_root_id#' } },
            },
        },
        {   -logic_name => 'hc_species_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::MSA::SqlHealthChecks',
            -parameters => {
                'mode'                      => 'species_tree',
                'binary'                    => 0,
                'n_missing_species_in_tree' => 0,
            },
        },
        # Copy data from the previous ancestral core database and update the ancestor names with new MLSS id
        {   -logic_name => 'copy_ancestral_data',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::CopyAncestralData',
            -parameters => {
                'program'       => $self->o('copy_ancestral_core_exe'),
                'reg_conf'      => $self->o('reg_conf'),
                'from_name'     => $self->o('prev_ancestral_db'),
                'to_dbc'        => $self->o('ancestral_db'),
                'msa_mlss_id'   => '#prev_mlss_id#',
            },
            -flow_into  => [ 'update_ancestor_names' ],
        },
        {   -logic_name => 'update_ancestor_names',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn' => $self->o('ancestral_db'),
                'sql'     => [
                    'UPDATE seq_region SET name = REPLACE(name, "_#prev_mlss_id#_", "_#mlss_id#_")',
                ],
            },
        },
        # Copy all the anchor_aligns for the genomes included in the new EPO MSA (subset of the previous one)
        {   -logic_name => 'copy_anchor_align_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'fan_branch_code'   => 1,
            },
            -flow_into  => {
                1 => { 'copy_anchor_align' => INPUT_PLUS() },
            },
        },
        {   -logic_name    => 'copy_anchor_align',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin',
            -parameters    => {
                'db_conn'    => '#prev_db#',
                'table'      => 'anchor_align',
                'inputquery' => 'SELECT anchor_align_id, #mlss_id#, anchor_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, score, num_of_organisms, num_of_sequences, evalue, untrimmed_anchor_align_id, is_overlapping FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE genome_db_id = #genome_db_id#',
            },
            -hive_capacity => 10,
        },
        # Transfer MLSS, GA* and dnafrag ids from the previous MLSS id to the current one, update the MSA and
        # ancestral core database, and finally remove the previous MSA information
        {   -logic_name => 'transfer_msa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::TransferAlignment',
            -parameters => {
                'method_type' => $self->o('method_type'),
            },
            -flow_into  => [ 'fire_gab_analyses' ],
        },
        {   -logic_name => 'fire_gab_analyses',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => [ 'affected_gabs_factory' ],
                'A->1' => WHEN(
                    '#method_type# eq "epo"' => [ 'sync_ancestral_database' ],
                    ELSE                        [ 'remove_prev_mlss' ],
                ),
            },
        },
        {   -logic_name => 'affected_gabs_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGABFactory',
            -flow_into  => {
                '2->A' => [ 'update_gab' ],
                'A->1' => [ { 'minimize_gab_check' => \%dc_analysis_params } ]
            }
        },
        {   -logic_name        => 'minimize_gab_check',
            -module            => 'Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan',
            -max_retry_count   => 0,
		},
        {   -logic_name     => 'update_gab',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGAB',
            -rc_name        => '1Gb_job',
            -batch_size     => 50,
            -hive_capacity  => 250,
            -flow_into      => {
                2   => '?accu_name=ancestor_names&accu_address=[]&accu_input_variable=name',
            }
        },
        {   -logic_name => 'sync_ancestral_database',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::SyncAncestralDB',
            -parameters => {
                'ancestral_db' => $self->o('ancestral_db'),
            },
            -flow_into  => [ 'remove_prev_mlss' ],
        },
        {   -logic_name => 'remove_prev_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'wrap_in_transaction' => 1,
                'sql'                 => [
                    'SET FOREIGN_KEY_CHECKS = 0',
                    'DELETE stn, stnt FROM species_tree_node stn LEFT JOIN species_tree_node_tag stnt USING (node_id) JOIN species_tree_root str USING (root_id) WHERE method_link_species_set_id = #prev_mlss_id#',
                    'SET FOREIGN_KEY_CHECKS = 1',
                    'DELETE FROM species_tree_root WHERE method_link_species_set_id = #prev_mlss_id#',
                    'DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = #prev_mlss_id#',
                    'DELETE FROM method_link_species_set WHERE method_link_species_set_id = #prev_mlss_id#',
                ],
            },
            -flow_into  => {
                '1->A'  => WHEN( '#run_gerp# && #method_type# eq "pecan"' => [ 'set_gerp_neutral_rate' ] ),
                'A->1'  => [ 'create_neighbour_nodes_jobs_alignment' ],
                '1'     => WHEN( '#method_type# eq "epo"' => [ 'epo_extended_rib' ] ),
            },
        },
        # EPO Extended pipeline
        {   -logic_name => 'epo_extended_rib',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CheckSwitch',
            -parameters => {
                'switch_name' => 'lastz_complete',
            },
            -flow_into  => [ 'create_default_pairwise_mlss' ],
            -max_retry_count => 0,
        },
        {   -logic_name => 'create_extended_genome_jobs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT genomic_align_block_id, #ext_mlss_id# FROM genomic_align ga LEFT JOIN dnafrag USING (dnafrag_id) WHERE method_link_species_set_id = #mlss_id# AND coord_system_name != "ancestralsegment" GROUP BY genomic_align_block_id',
                'column_names'  => [ 'genomic_align_block_id', 'mlss_id' ],
            },
            -rc_name => '4Gb_job',
            -flow_into => {
                '2->A' => [ 'extended_genome_alignment' ],
                'A->1' => [ 'set_internal_ids_epo_extended' ],
            },
        },
        {   -logic_name => 'set_internal_ids_epo_extended',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection',
            -parameters => {
                'method_link_species_set_id' => '#ext_mlss_id#',
            },
            -flow_into  => {
                1   => { 'create_neighbour_nodes_jobs_alignment' => { 'mlss_id' => '#ext_mlss_id#', 'method_type' => 'epo_extended' } },
            },
        },
        # Create/update the neighbour nodes for both EPO and EPO Extended MSAs
        {   -logic_name => 'create_neighbour_nodes_jobs_alignment',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT gat2.root_id FROM genomic_align_tree gat1 LEFT JOIN genomic_align ga USING (node_id) JOIN genomic_align_tree gat2 USING (root_id) WHERE gat2.parent_id IS NULL AND ga.method_link_species_set_id = #mlss_id# GROUP BY gat2.root_id',
                'column_names'  => [ 'root_id' ],
            },
            -rc_name    => '2Gb_job',
            -flow_into  => {
                '2->A' => [ 'set_neighbour_nodes' ],
                'A->1' => { 'update_max_alignment_length' => { 'method_link_species_set_id' => '#mlss_id#', 'method_type' => '#method_type#' } },
            },
        },
        {   -logic_name    => 'set_neighbour_nodes',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::EpoExtended::SetNeighbourNodes',
            -rc_name       => '2Gb_job',
            -batch_size    => 10,
            -hive_capacity => 20,
        },
        # Flow Mercator-Pecan GABs to compute their GERPs
        {   -logic_name => 'flow_gabs',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'    => 'SELECT genomic_align_block_id, #mlss_id# FROM genomic_align_block WHERE method_link_species_set_id = #mlss_id#',
                'column_names'  => [ 'genomic_align_block_id', 'mlss_id' ],
            },
            -flow_into  => {
                2   => [ 'gerp' ],
            },
        },
        # Update max alignment MLSS tag
        {   -logic_name => 'update_max_alignment_length',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::UpdateMaxAlignmentLength',
            -rc_name    => '2Gb_job',
            -flow_into  => [ 'healthcheck_factory' ],
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAncestral::pipeline_analyses_epo_ancestral($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended::pipeline_analyses_epo_ext_alignment($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoExtended::pipeline_analyses_healthcheck($self) },
    ];
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;
    # Set MLSS tag only for EPO MSAs and swap order for set_gerp_mlss_tag and set_mlss_tag
    # Change the parameters to work with "local" parameters instead of pipeline-wide ones
    $analyses_by_name->{'set_gerp_mlss_tag'}->{'-parameters'} = { 'sql' => [
        'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#cs_mlss_id#, "msa_mlss_id", #ext_mlss_id#)',
        'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#ce_mlss_id#, "msa_mlss_id", #ext_mlss_id#)',
    ]};
    delete $analyses_by_name->{'set_gerp_mlss_tag'}->{'-flow_into'};
    $analyses_by_name->{'set_mlss_tag'}->{'-parameters'} = { 'sql'   => [
        'INSERT INTO method_link_species_set_tag (method_link_species_set_id, tag, value) VALUES (#ext_mlss_id#, "base_mlss_id", #mlss_id#)',
    ]};
    $analyses_by_name->{'set_mlss_tag'}->{'-flow_into'} = WHEN( '#run_gerp#' => { 'set_gerp_mlss_tag' => INPUT_PLUS() } );
    # Flow to copy_ancestral_data to copy the previous ancestral core database
    $analyses_by_name->{'find_ancestral_seq_gdb'}->{'-flow_into'}->{1} = [ 'copy_ancestral_data' ];
    # Link GERP analysis capacities with parameter
    $analyses_by_name->{'gerp'}->{'-analysis_capacity'} = $self->o('gerp_capacity');
    $analyses_by_name->{'gerp_himem'}->{'-analysis_capacity'} = $self->o('gerp_capacity');
    # Update EPO Extended analyses to deal with "local" parameters and change the flow between analyses to
    # integrate Mercator-Pecan compatibility
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-parameters'} = {
        'new_method_link_species_set_id'  => '#ext_mlss_id#',
        'base_method_link_species_set_id' => '#mlss_id#',
        'pairwise_location'               => $self->o('pairwise_location'),
        'prev_epo_db'                     => '#reuse_db#',
    };
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-flow_into'}->{1} = WHEN(
        '#run_gerp#' => [ 'set_gerp_neutral_rate' ],
        ELSE            [ 'create_extended_genome_jobs' ]
    );
    $analyses_by_name->{'set_gerp_neutral_rate'}->{'-flow_into'}->{1} = WHEN(
        '#method_type# eq "epo"' => [ 'create_extended_genome_jobs' ],
        ELSE                        [ 'flow_gabs' ]
    );
    # Set MLSS id to EPO Extended to ensure correct link is flown to GERP analyses
    $analyses_by_name->{'extended_genome_alignment'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';
    $analyses_by_name->{'extended_genome_alignment_himem'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';
    $analyses_by_name->{'extended_genome_alignment_hugemem'}->{'-parameters'}->{'mlss_id'} = '#ext_mlss_id#';
    # Run HCs on GERPs only for Mercator-Pecan and EPO Extended MLSS ids
    $analyses_by_name->{'healthcheck_factory'}->{'-flow_into'} = {
        '1->A' => WHEN (
            '#run_gerp# && #method_type# ne "epo"' => { 'conservation_score_healthcheck' => [
                { 'test' => 'conservation_jobs', 'logic_name' => 'gerp', 'method_link_type' => '#method_type#' },
                { 'test' => 'conservation_scores', 'method_link_species_set_id' => '#cs_mlss_id#' },
            ]}
        ),
        'A->1' => WHEN(
            'not #skip_multiplealigner_stats#' => { 'multiplealigner_stats_factory' => { 'mlss_id' => '#method_link_species_set_id#' } },
            ELSE                                  [ 'end_pipeline' ]
        ),
    };
}


1;
