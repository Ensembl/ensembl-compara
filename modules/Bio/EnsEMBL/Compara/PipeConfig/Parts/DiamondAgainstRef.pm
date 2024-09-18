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

Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstRef

=head1 DESCRIPTION

    This is a partial PipeConfig to Diamond search a member_id list against blast_db

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstRef;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

sub pipeline_analyses_diamond_against_refdb {
    my ($self) = @_;

    my %blastp_parameters = (
        'diamond_exe'   => $self->o('diamond_exe'),
        'blast_params'  => $self->o('blast_params'),
        'evalue_limit'  => $self->o('evalue_limit'),
    );

    return [
        {   -logic_name         => 'diamond_blastp',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondBlastp',
            -parameters         => {
                %blastp_parameters,
            },
            -rc_name            => '1Gb_4c_24_hour_job',
            -flow_into          => {
               -1 => [ 'diamond_blastp_himem' ],  # MEMLIMIT
            },
            -hive_capacity      => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'diamond_blastp_himem',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DiamondBlastp',
            -parameters         => {
                %blastp_parameters,
            },
            -rc_name            => '2Gb_4c_24_hour_job',
            -priority           => 20,
            -hive_capacity      => $self->o('blastpu_capacity'),
        },

    ];
}

1;
