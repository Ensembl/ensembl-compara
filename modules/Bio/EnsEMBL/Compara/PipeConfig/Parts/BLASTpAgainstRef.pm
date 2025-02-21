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

Bio::EnsEMBL::Compara::PipeConfig::Parts::BLASTpAgainstRef

=head1 DESCRIPTION

    This is a partial PipeConfig to BLAST a member_id list against given blast_db

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::BLASTpAgainstRef;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version v2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
    }
}

sub pipeline_analyses_blastp_against_refdb {
    my ($self) = @_;

    my %blastp_parameters = (
        'blast_bin_dir' => $self->o('blast_bin_dir'),
        'blast_params'  => "#expr(#all_blast_params#->[2])expr#",
        'evalue_limit'  => "#expr(#all_blast_params#->[3])expr#",
        'blast_db'      => $self->o('blast_db'),
    );

    return [
        {   -logic_name         => 'blastp_unannotated',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                %blastp_parameters,
            },
            -rc_name       => '500Mb_6_hour_job',
            -flow_into => {
               -1 => [ 'blastp_unannotated_himem' ],  # MEMLIMIT
               -2 => 'break_batch',
            },
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'blastp_unannotated_himem',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                %blastp_parameters,
            },
            -rc_name       => '2Gb_6_hour_job',
            -flow_into => {
               -2 => 'break_batch',
            },
            -priority      => 20,
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'break_batch',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BreakBlastBatch',
            -flow_into  => {
                2 => 'blastp_unannotated_no_runlimit',
            }
        },

        {   -logic_name         => 'blastp_unannotated_no_runlimit',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                %blastp_parameters,
            },
            -flow_into => {
               -1 => [ 'blastp_unannotated_himem_no_runlimit' ],  # MEMLIMIT
            },
            -hive_capacity => $self->o('blastpu_capacity'),
        },

        {   -logic_name         => 'blastp_unannotated_himem_no_runlimit',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BlastpUnannotated',
            -parameters         => {
                %blastp_parameters,
            },
            -rc_name       => '2Gb_job',
            -priority      => 20,
            -hive_capacity => $self->o('blastpu_capacity'),
        },

    ];
}

1;
