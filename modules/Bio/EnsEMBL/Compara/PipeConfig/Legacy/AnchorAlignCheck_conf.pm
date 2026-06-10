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

Bio::EnsEMBL::Compara::PipeConfig::Legacy::AnchorAlignCheck_conf

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Legacy::AnchorAlignCheck_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'epo_db' => undef,
        'collection' => undef,
        'division' => undef,

        'pipeline_name' => $self->o('collection') . '_' . $self->o('division')  . '_anchor_align_check_' . $self->o('rel_with_suffix'),

        'work_dir' => $self->o('pipeline_dir'),

        'enredo_params' => ' --min-score 0 --max-gap-length 200000 --max-path-dissimilarity 4 --min-length 10000 --min-regions 2 --min-anchors 3 --max-ratio 3 --simplify-graph 7 --bridges -o ',

        'trim_anchor_align_batch_size' => 20,
        'trim_anchor_align_capacity' => 500,
    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},
        $self->pipeline_create_commands_rm_mkdir(['work_dir']),
    ];
}


sub pipeline_wide_parameters {
    my $self = shift @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'epo_db' => $self->o('epo_db'),
        'compara_db' => $self->pipeline_url(),
        'collection' => $self->o('collection'),
        'division' => $self->o('division'),

        'work_dir' => $self->o('work_dir'),

        'genome_dumps_dir' => $self->o('genome_dumps_dir'),
    };
}


sub pipeline_checks_pre_init {
    my ($self) = @_;

    if (!defined $self->o('collection')) {
        die("A collection must be specified with the 'collection' pipeline parameter");
    }

    if (!defined $self->o('epo_db')) {
        die("An EPO database must be specified with the 'epo_db' pipeline parameter");
    }
}


sub core_pipeline_analyses {
    my ($self) = @_;

    return [

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -input_ids  => [ {} ],
            -parameters => {
                'column_names' => [ 'table' ],
                'db_conn'      => '#epo_db#',
                'inputlist'    => [ 'dnafrag', 'genome_db' ],
            },
            -flow_into => {
                '2->A' => { 'copy_table' => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' } },
                'A->1' => 'copy_table_funnel_check',
            },
        },

        {   -logic_name => 'copy_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'filter_cmd' => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
        },

        {   -logic_name => 'copy_table_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => 'copy_untrimmed_anchor_aligns',
        },

        {   -logic_name => 'copy_untrimmed_anchor_aligns',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithJoin',
            -parameters => {
                'db_conn'    => '#epo_db#',
                'table'      => 'anchor_align',
                'inputquery' => q/
                    SELECT * FROM anchor_align
                    WHERE untrimmed_anchor_align_id IS NULL
                    AND is_overlapping = 0
                /,
            },
            -flow_into  => 'check_consistent_mlss',
        },

        {   -logic_name => 'check_consistent_mlss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'query' => 'SELECT DISTINCT method_link_species_set_id FROM anchor_align',
                'expected_size' => 1,
            },
            -flow_into  => 'fire_anchor_align_trimming',
        },

        {   -logic_name => 'fire_anchor_align_trimming',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'trim_anchor_align_factory' ],
                'A->1'  => [ 'trim_anchor_align_funnel_check' ],
            },
        },

        {   -logic_name => 'trim_anchor_align_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'  => q/
                    SELECT DISTINCT method_link_species_set_id, anchor_id
                    FROM anchor_align
                    WHERE untrimmed_anchor_align_id IS NULL
                    AND is_overlapping = 0
                /,
            },
            -flow_into  => { 2 => 'trim_anchor_align' },
            -rc_name    => '4Gb_24_hour_job',
        },

        {   -logic_name => 'trim_anchor_align',
            -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
            -parameters => {
                'ortheus_c_exe' => $self->o('ortheus_c_exe'),
            },
            -flow_into  => { -1 => 'trim_anchor_align_himem' },
            -hive_capacity => $self->o('trim_anchor_align_capacity'),
            -batch_size => $self->o('trim_anchor_align_batch_size'),
            -rc_name    => '2Gb_job',
        },

        {   -logic_name => 'trim_anchor_align_himem',
            -module     => 'Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign',
            -parameters => {
                'ortheus_c_exe' => $self->o('ortheus_c_exe'),
            },
            -flow_into  => { -1 => 'ignore_huge_trim_anchor_align' },
            -hive_capacity => $self->o('trim_anchor_align_capacity'),
            -batch_size => $self->o('trim_anchor_align_batch_size'),
            -rc_name    => '8Gb_job',
        },

        {   -logic_name => 'ignore_huge_trim_anchor_align',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -meadow_type=> 'LOCAL',
        },

        {   -logic_name => 'trim_anchor_align_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => 'fire_enredo',
        },

        {   -logic_name => 'fire_enredo',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names' => [ 'db_label', 'db_conn' ],
                'inputlist'    => [ ['epo_db', '#epo_db#'], ['compara_db', '#compara_db#'] ],
            },
            -flow_into  => {
                '2->A'  => [ 'dump_mappings_to_file' ],
                'A->1'  => [ 'enredo_funnel_check' ],
            },
        },

        {   -logic_name => 'dump_mappings_to_file',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters => {
                'append'              => [ '-N', '-B', '-q' ],
                'enredo_mapping_file' => '#work_dir#/enredo_input.#db_label#.txt',
                'output_file'         => '#enredo_mapping_file#',
                'input_query'         => q/
                    SELECT
                        aa.anchor_id,
                        gdb.name,
                        df.name,
                        aa.dnafrag_start,
                        aa.dnafrag_end,
                        CASE aa.dnafrag_strand WHEN 1 THEN "+" ELSE "-" END,
                        aa.num_of_organisms,
                        aa.score
                    FROM
                        anchor_align aa
                    INNER JOIN
                        dnafrag df ON aa.dnafrag_id = df.dnafrag_id
                    INNER JOIN
                        genome_db gdb ON gdb.genome_db_id = df.genome_db_id
                    WHERE
                        untrimmed_anchor_align_id IS NOT NULL
                    ORDER BY
                        gdb.name, df.name, aa.dnafrag_start
                /,
            },
            -flow_into => {
                1 => {
                    'run_enredo' => { 'enredo_mapping_file' => '#enredo_mapping_file#', 'db_label' => '#db_label#' },
                },
            },
        },

        {   -logic_name => 'run_enredo',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '8Gb_job',
            -parameters => {
                'cmd' => '#enredo_exe# #enredo_params# #enredo_output_file# #enredo_mapping_file#',
                'enredo_exe' => $self->o('enredo_exe'),
                'enredo_output_file' => '#work_dir#/enredo_output.#db_label#.txt',
                'enredo_params' => $self->o('enredo_params'),
            },
        },

        {   -logic_name => 'enredo_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => 'compare_enredo_regions',
        },

        {   -logic_name => 'compare_enredo_regions',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'cmd' => '#compare_enredo_regions_exe# -a #epo_enredo_output_file# -b #compara_enredo_output_file# -o #comparison_output_file#',
                'compare_enredo_regions_exe' => $self->o('compare_enredo_regions_exe'),
                'comparison_output_file' => '#work_dir#/enredo_output.jaccard.tsv',
                'epo_enredo_output_file' => '#work_dir#/enredo_output.epo_db.txt',
                'compara_enredo_output_file' => '#work_dir#/enredo_output.compara_db.txt',
            },
        },
    ];
}


1;
