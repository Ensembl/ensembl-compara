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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ReindexMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ReindexMembers_conf \
        -host mysql-ens-compara-prod-X -port XXXX \
        -collection <collection>

=head1 DESCRIPTION

A Metazoa-specific version of the ReindexMembers pipeline.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::ReindexMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'      => 'metazoa',

        'member_type'   => 'protein',

        'prev_tree_db' => $self->o('collection') . '_ptrees_prev',
    };
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    $analyses_by_name->{'all_trees_factory'}->{'-rc_name'} = '2Gb_24_hour_job';
    $analyses_by_name->{'copy_table_from_prev_db'}->{'-rc_name'} = '1Gb_24_hour_job';

    $analyses_by_name->{'hc_members_per_genome'}->{'-parameters'}->{'allow_ambiguity_codes'} = 1;
}


1;
