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

Bio::EnsEMBL::Compara::PipeConfig::Example::LoadMembersQfo_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::LoadMembersQfo_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the LoadMembers pipeline for Quest-for-Orthologs dataset.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::LoadMembersQfo_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'      => 'qfo',
        'collection'    => undef,
        'master_db'     => undef,
        'ncbi_db'       => 'ncbi_taxonomy',

        'reuse_member_db' => undef,

        'curr_file_sources_locs' => [ '/homes/cristig/workbench/master/ensembl-compara/conf/qfo/qfo_2021.json' ],

    #load uniprot members for family pipeline
        'load_uniprot_members'      => 0,

        # list of species that got an annotation update
        'expected_updates_file' => undef,
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'ncbi_db' => $self->o('ncbi_db'),
    },
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'check_versions_match'}->{'-parameters'} = { 'manual_ok' => 1 };
    delete $analyses_by_name->{'copy_table_from_master'}->{'-parameters'}->{'src_db_conn'};
    $analyses_by_name->{'copy_table_from_master'}->{'-parameters'}->{'src_db_conn'} = '#ncbi_db#';

}
1;

