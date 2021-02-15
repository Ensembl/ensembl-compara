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

Bio::EnsEMBL::Compara::PipeConfig::EPOwith2x_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EPOwith2x_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV -species_set_name <species_set_name> -low_epo_mlss_id <id> -high_epo_mlss_id <id>

=head1 DESCRIPTION

    This pipeline runs EPO and EPO2x together. For more information on each pipeline, see their respective PipeConfig files:
    - Bio::EnsEMBL::Compara::PipeConfig::EPO_conf
    - Bio::EnsEMBL::Compara::PipeConfig::EpoLowCoverage_conf

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EPOwith2x_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoLowCoverage;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => $self->o('species_set_name').'_epo_with2x_'.$self->o('rel_with_suffix'),
        'master_db'     => 'compara_master',

        # database containing the anchors for mapping
        'compara_anchor_db' => $self->o('species_set_name').'_epo_anchors',
        # the previous database to reuse the anchor mappings
        'reuse_db'          => $self->o('species_set_name').'_epo_prev',

        'ancestral_sequences_name'         => 'ancestral_sequences',
        'ancestral_sequences_display_name' => 'Ancestral sequences',

        # Executable parameters
        'mapping_params'    => { bestn=>11, gappedextension=>"no", softmasktarget=>"no", percent=>75, showalignment=>"no", model=>"affine:local", },
        'enredo_params'     => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',

        # Dump directory
        'work_dir'            => $self->o('pipeline_dir'),
        'enredo_output_file'  => $self->o('work_dir').'/enredo_output.txt',
        'bed_dir'             => $self->o('work_dir').'/bed',
        'feature_dir'         => $self->o('work_dir').'/feature_dump',
        'enredo_mapping_file' => $self->o('work_dir').'/enredo_input.txt',
        'bl2seq_dump_dir'     => $self->o('work_dir').'/bl2seq', # location for dumping sequences to determine strand (for bl2seq)
        'bl2seq_file_stem'    => '#bl2seq_dump_dir#/bl2seq',
        'output_dir'          => '#feature_dir#', # alias

        # Capacities
        'low_capacity'                  => 10,
        'map_anchors_batch_size'        => 5,
        'map_anchors_capacity'          => 2000,
        'trim_anchor_align_batch_size'  => 20,
        'trim_anchor_align_capacity'    => 500,

        # Options
        #skip this module if set to 1
        'skip_multiplealigner_stats' => 0,
        # dont dump the MT sequence for mapping
        'only_nuclear_genome'        => 1,
        # add MT dnafrags separately (1) or not (0) to the dnafrag_region table
        'add_non_nuclear_alignments' => 1,
        # batch size of anchor sequences to map
        'anchor_batch_size'          => 1000,

        # The ancestral_db is created on the same server as the pipeline_db
        'ancestral_db' => { # core ancestral db
            -driver   => $self->o('pipeline_db', '-driver'),
            -host     => $self->o('pipeline_db', '-host'),
            -port     => $self->o('pipeline_db', '-port'),
            -species  => $self->o('ancestral_sequences_name'),
            -user     => $self->o('pipeline_db', '-user'),
            -pass     => $self->o('pipeline_db', '-pass'),
            -dbname   => $self->o('dbowner').'_'.$self->o('species_set_name').'_ancestral_core_'.$self->o('rel_with_suffix'),
        },

        # ----- EpoLowCoverage settings ----- #

        'run_gerp'          => 1,
        'gerp_window_sizes' => [1,10,100,500], #gerp window sizes

        'low_epo_mlss_id'  => $self->o('low_epo_mlss_id'),  # mlss_id for low coverage epo alignment
        'base_epo_mlss_id' => $self->o('high_epo_mlss_id'), # mlss_id for the base alignment we're topping up
                                                            # (can be EPO or EPO_EXTENDED)
        'max_block_size'   => 1000000,                       #max size of alignment before splitting

        #default location for pairwise alignments (can be a string or an array-ref)
        'pairwise_location' => [ qw(compara_prev lastz_batch_* unidir_lastz) ],
        'lastz_complete'    => 0, # set to 1 when all relevant LASTZs have complete
        'epo_db'            => $self->pipeline_url(),
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # inheriting database and hive tables' creation
        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'bed_dir', 'feature_dir', 'bl2seq_dump_dir']),
    ];
}

sub pipeline_wide_parameters {
    my $self = shift @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'low_epo_mlss_id'  => $self->o('low_epo_mlss_id'),
        'high_epo_mlss_id' => $self->o('high_epo_mlss_id'),
        'base_epo_mlss_id' => $self->o('base_epo_mlss_id'),
        'species_set_name' => $self->o('species_set_name'),

        # directories
        'work_dir'              => $self->o('work_dir'),
        'feature_dir'           => $self->o('feature_dir'),
        'enredo_output_file'    => $self->o('enredo_output_file'),
        'bed_dir'               => $self->o('bed_dir'),
        'genome_dumps_dir'      => $self->o('genome_dumps_dir'),
        'enredo_mapping_file'   => $self->o('enredo_mapping_file'),
        'bl2seq_dump_dir'       => $self->o('bl2seq_dump_dir'),
        'bl2seq_file_stem'      => $self->o('bl2seq_file_stem'),

        # databases
        'compara_anchor_db' => $self->o('compara_anchor_db'),
        'master_db'         => $self->o('master_db'),
        'reuse_db'          => $self->o('reuse_db'),
        'ancestral_db'      => $self->o('ancestral_db'),
        'epo_db'            => $self->o('epo_db'),

        # options
        'run_gerp'       => $self->o('run_gerp'),
        'lastz_complete' => $self->o('lastz_complete'),
    };

}

sub core_pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'start_prepare_databases',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [{
                mlss_id => '#high_epo_mlss_id#',
            }],
            -flow_into  => {
                '1->A' => [ 'copy_table_factory', 'set_internal_ids', 'drop_ancestral_db' ],
                'A->1' => 'reuse_anchor_align_factory',
            }
        },

        {   -logic_name => 'mlss_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => [
                    [
                        '#high_epo_mlss_id#',
                        ['EPO'],
                        ['high_epo_mlss_id'],
                        '#high_epo_mlss_id#',
                        1, # store reuse species sets for high coverage species
                    ],
                    [
                        '#low_epo_mlss_id#',
                        '#expr(#run_gerp# ? ["EPO_EXTENDED", "GERP_CONSTRAINED_ELEMENT", "GERP_CONSERVATION_SCORE"] : ["EPO_EXTENDED"])expr#',
                        '#expr(#run_gerp# ? ["low_epo_mlss_id", "ce_mlss_id", "cs_mlss_id"] : ["low_epo_mlss_id"])expr#',
                        undef,
                        0 # do not store reuse species sets for low coverage species
                    ],
                ],
                'column_names' => [ 'mlss_id', 'whole_method_links', 'param_names', 'filter_by_mlss_id', 'store_reuse_ss' ],
            },
            -flow_into  => {
                '2->A' => { 'create_mlss_ss' => INPUT_PLUS() },
                'A->1' => WHEN(
                    '#run_gerp#' => [ 'set_gerp_mlss_tag' ],
                    ELSE            [ 'set_mlss_tag' ],
                ),
            }
        },

        {   -logic_name => 'setup_low_coverage_alignment',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => ['dump_mappings_to_file', 'check_for_lastz'],
        },

        {   -logic_name => 'check_for_lastz',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => WHEN( '#lastz_complete#' => { 'create_default_pairwise_mlss' => { 'mlss_id' => '#low_epo_mlss_id#' }}),
        },

        {   -logic_name => 'set_internal_ids_low_epo',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection',
            -parameters => {
                method_link_species_set_id => '#low_epo_mlss_id#',
            },
            -flow_into => [ 'alignment_mlss_factory' ],
        },

        {   -logic_name => 'alignment_mlss_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputlist'    => ['#high_epo_mlss_id#', '#low_epo_mlss_id#'],
                'column_names' => ['mlss_id'],
            },
            -flow_into => {
                2 => ['create_neighbour_nodes_jobs_alignment'],
            },
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOMapAnchors::pipeline_analyses_epo_anchor_mapping($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EPOAlignment::core_pipeline_analyses_epo_alignment($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoLowCoverage::pipeline_analyses_epo2x_alignment($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::EpoLowCoverage::pipeline_analyses_healthcheck($self) },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    # load genomes from low_epo_mlss_id by hijacking the dataflow
    $analyses_by_name->{'offset_tables'}->{'-flow_into'} = { 1 => { 'load_genomedb_factory' => { 'mlss_id' => '#low_epo_mlss_id#' } } };

    # load_genomedb_factory should connect to the mlss_factory
    $analyses_by_name->{'load_genomedb_factory'}->{'-flow_into'}->{'A->1'} = [ 'mlss_factory' ];

    # disconnect set_mlss_tag
    delete $analyses_by_name->{'set_mlss_tag'}->{'-flow_into'};

    # flow 2 "make_species_tree" jobs and add semaphore
    $analyses_by_name->{'create_mlss_ss'}->{'-flow_into'} = 'make_species_tree';
    delete $analyses_by_name->{'create_mlss_ss'}->{'-parameters'};
    delete $analyses_by_name->{'make_species_tree'}->{'-flow_into'};

    # set mlss_id for anchor mapping
    $analyses_by_name->{'reuse_anchor_align'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';
    $analyses_by_name->{'map_anchors'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';
    $analyses_by_name->{'map_anchors_himem'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';
    $analyses_by_name->{'map_anchors_no_server'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';
    $analyses_by_name->{'map_anchors_no_server_himem'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';

    # Rewire "create_default_pairwise_mlss" and "dump_mappings_to_file" after having trimmed the anchors
    $analyses_by_name->{'trim_anchor_align_factory'}->{'-flow_into'} = {
        '2->A' => $analyses_by_name->{'trim_anchor_align_factory'}->{'-flow_into'}->{2},
        'A->1' => [ 'setup_low_coverage_alignment' ],
    };
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-flow_into'}->{1} = WHEN( '#run_gerp#' => [ 'set_gerp_neutral_rate' ]);
    $analyses_by_name->{'create_default_pairwise_mlss'}->{'-parameters'}->{'prev_epo_db'} = '#reuse_db#';
    delete $analyses_by_name->{'set_gerp_neutral_rate'}->{'-flow_into'}->{1};

    # Make Enredo work only on the high-coverage genomes
    $analyses_by_name->{'load_dnafrag_region'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';

    # link "ortheus*" analyses directly to "low_coverage_genome_alignment"
    $analyses_by_name->{'ortheus'}->{'-flow_into'}->{1} = 'low_coverage_genome_alignment';
    $analyses_by_name->{'ortheus'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';
    $analyses_by_name->{'ortheus_high_mem'}->{'-flow_into'}->{1} = 'low_coverage_genome_alignment';
    $analyses_by_name->{'ortheus_high_mem'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';
    $analyses_by_name->{'ortheus_huge_mem'}->{'-flow_into'}->{1} = 'low_coverage_genome_alignment';
    $analyses_by_name->{'ortheus_huge_mem'}->{'-parameters'}->{'mlss_id'} = '#high_epo_mlss_id#';

    # set mlss_id for "low_coverage_genome_alignment*"
    $analyses_by_name->{'low_coverage_genome_alignment'}->{'-parameters'}->{'mlss_id'} = '#low_epo_mlss_id#';
    $analyses_by_name->{'low_coverage_genome_alignment_again'}->{'-parameters'}->{'mlss_id'} = '#low_epo_mlss_id#';
    $analyses_by_name->{'low_coverage_genome_alignment_himem'}->{'-parameters'}->{'mlss_id'} = '#low_epo_mlss_id#';
    $analyses_by_name->{'low_coverage_genome_alignment_hugemem'}->{'-parameters'}->{'mlss_id'} = '#low_epo_mlss_id#';

    # block analyses until LASTZ are complete
    $analyses_by_name->{'low_coverage_genome_alignment'}->{'-wait_for'} = 'create_default_pairwise_mlss';
    $analyses_by_name->{'gerp'}->{'-wait_for'} = 'set_gerp_neutral_rate';

    # add "set_internal_ids_low_epo" to "load_dnafrag_region"
    $analyses_by_name->{'load_dnafrag_region'}->{'-flow_into'}->{'A->1'} = { 'set_internal_ids_low_epo' => {} };

    # ensure mlss_ids are flowed with their root_ids
    $analyses_by_name->{'create_neighbour_nodes_jobs_alignment'}->{'-parameters'}->{'inputquery'} = 'SELECT gat2.root_id, #mlss_id# as mlss_id FROM genomic_align_tree gat1 LEFT JOIN genomic_align ga USING(node_id) JOIN genomic_align_tree gat2 USING(root_id) WHERE gat2.parent_id IS NULL AND ga.method_link_species_set_id = #mlss_id# GROUP BY gat2.root_id';
}

1;
