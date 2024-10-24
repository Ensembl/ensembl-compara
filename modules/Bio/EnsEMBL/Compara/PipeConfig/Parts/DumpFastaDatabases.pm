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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpFastaDatabases

=head1 DESCRIPTION

A pipeline building block for dumping members to fasta and then splitting
the fasta into parts

=cut


package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpFastaDatabases;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


sub pipeline_analyses_dump_fasta_dbs {
    my ($self) = @_;
    return [
        {   -logic_name => 'dump_full_fasta',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DumpMembersIntoFasta',
            -hive_capacity  => 10,
            -rc_name    => '1Gb_job',
            -flow_into  => ['split_fasta_into_parts', 'make_diamond_db'],
        },

        {   -logic_name => 'split_fasta_into_parts',
            -module     => 'ensembl.compara.runnable.SplitFasta',
            -language   => 'python3',
            -parameters => {
                'num_parts' => $self->o('num_fasta_parts'),
            },
            -rc_name    => '1Gb_job',
        },

        {   -logic_name => 'make_diamond_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters => {
                'diamond_exe' => $self->o('diamond_exe'),
                'cmd'         => '#diamond_exe# makedb --in #fasta_name# -d #db_name#',
                # db_name should be #fasta_name# with .fasta removed from the end - hive can do that
                'db_name'     => '#expr( ($_ = #fasta_name#) and $_ =~ s/\.fasta$// and $_)expr#',
            },
            -rc_name    => '1Gb_job',
        },
    ];
}

1;
