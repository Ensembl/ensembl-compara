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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements

=head1 DESCRIPTION

This PipeConfig contains the core analyses required to dump the contrained
elements as BigBED files.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpConstrainedElements;

use strict;
use warnings;
no warnings 'qw';

use Bio::EnsEMBL::Hive::Version 2.4;

sub pipeline_analyses_dump_constrained_elems {
    my ($self) = @_;
    return [

        {   -logic_name     => 'mkdir_constrained_elems',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConstrainedElements',
            -flow_into      => [ 'genomedb_factory_ce' ],
        },

        {   -logic_name     => 'genomedb_factory_ce',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters     => {
                'extra_parameters'      => [ 'name' ],
            },
            -flow_into      => {
                '2->A' => [ 'dump_constrained_elements' ],
                'A->1' => [ 'md5sum_ce' ],
            },
        },

        {   -logic_name     => 'dump_constrained_elements',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => '#dump_features_exe# --feature ce_#mlss_id# --compara_db #compara_db# --species #name# --lex_sort --reg_conf "#registry#" | tail -n+2 > #bed_file#',
            },
            -hive_capacity => $self->o('dump_ce_capacity'),
            -flow_into      => [ 'check_not_empty' ],
        },

        {   -logic_name     => 'check_not_empty',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CheckNotEmpty',
            -parameters     => {
                'min_number_of_lines'   => 1,   # The header is always present
                'filename'              => '#bed_file#',
            },
            -flow_into      => [ 'convert_to_bigbed' ],
        },

        {   -logic_name     => 'convert_to_bigbed',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConvertToBigBed',
            -parameters     => {
                'big_bed_exe'   => $self->o('big_bed_exe'),
                'autosql_file'  => $self->o('bigbed_autosql'),
                'bed_type'      => 'bed3+3',
            },
        },

        {   -logic_name     => 'md5sum_ce',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => 'cd #ce_output_dir#; md5sum *.bb > MD5SUM',
            },
            -flow_into      =>  [ 'readme_ce' ],
        },

        {   -logic_name     => 'readme_ce',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters     => {
                'cmd'   => [qw(cp -af #ce_readme# #ce_output_dir#/README)],
            },
        },
    ];
}

1;
