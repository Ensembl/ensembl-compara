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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements

=head1 DESCRIPTION

This PipeConfig contains the core analyses required to dump the contrained
elements as BigBED files.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;  # For INPUT_PLUS

sub pipeline_analyses_dump_constrained_elems {
    my ($self) = @_;
    return [

        {   -logic_name     => 'mkdir_constrained_elems',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConstrainedElements',
            -rc_name        => '1Gb_job',
            -flow_into      => [ 'genomedb_factory_ce' ],
        },

        {   -logic_name     => 'genomedb_factory_ce',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -rc_name        => '1Gb_job',
            -parameters     => {
                'extra_parameters'      => [ 'name' ],
            },
            -flow_into      => {
                '2->A' => [ 'fetch_exp_ce_line_count' ],
                'A->1' => [ 'ce_funnel_check' ],
            },
        },

        {   -logic_name => 'ce_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -rc_name    => '1Gb_job',
            -flow_into  => [ { 'md5sum_ce' => INPUT_PLUS() } ],
        },

        {   -logic_name => 'fetch_exp_ce_line_count',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'    => '#compara_db#',
                'inputquery' => q/
                    SELECT COUNT(DISTINCT dnafrag_id, dnafrag_start, dnafrag_end) AS exp_ce_line_count
                    FROM constrained_element
                    JOIN dnafrag USING (dnafrag_id)
                    WHERE method_link_species_set_id = #mlss_id#
                    AND genome_db_id = #genome_db_id#
                /,
            },
            -flow_into  => { 2 => { 'dump_constrained_elements' => INPUT_PLUS() } },
        },

        {   -logic_name     => 'dump_constrained_elements',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::SystemCommands',
            -parameters     => {
                'commands' => [
                    q/#dump_features_exe# --feature ce_#mlss_id# --compara_db #compara_db# --species #name# --lex_sort --reg_conf "#registry#" | tail -n+2 > #bed_file#/,
                    q/#textlint_exe# --threads 1 null #bed_file#/,
                    q/[[ $(grep -vc '^track\b' #bed_file#) -eq #exp_ce_line_count# ]]/,  # to keep it simple we do not count BED track lines
                ],
                'registry' => '#reg_conf#',
                'textlint_exe' => $self->o('textlint_exe'),
            },
            -rc_name        => '4Gb_24_hour_job',
            -hive_capacity  => $self->o('dump_ce_capacity'),
            -flow_into      => [ 'convert_to_bigbed' ],
        },

        {   -logic_name     => 'convert_to_bigbed',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConvertToBigBed',
            -rc_name        => '1Gb_job',
            -parameters     => {
                'big_bed_exe'   => $self->o('big_bed_exe'),
                'autosql_file'  => $self->o('bigbed_autosql'),
                'bed_type'      => 'bed3+3',
            },
        },

        {   -logic_name     => 'md5sum_ce',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name        => '1Gb_job',
            -parameters     => {
                'cmd'   => 'cd #ce_output_dir#; md5sum *.bb > MD5SUM',
            },
            -flow_into      =>  [ 'readme_ce' ],
        },

        {   -logic_name     => 'readme_ce',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name        => '1Gb_job',
            -parameters     => {
                'cmd'   => [qw(cp -af #ce_readme# #ce_output_dir#/README)],
            },
        },
    ];
}

1;
