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

Bio::EnsEMBL::Compara::PipeConfig::Protists::LoadMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Protists::LoadMembers_conf \
    -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the LoadMembers pipeline for Protists. Please, refer
to the parent class for further information.

Selected funnel analyses are blocked on pipeline initialisation.
These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Protists::LoadMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'  => 'protists',

        'do_nonblocking_checks' => 1,

        # Names of species we do not want to reuse this time
        # 'do_not_reuse_list' => [ 'bigelowiella_natans', 'emiliania_huxleyi' ],
        'do_not_reuse_list' => [],

        # "Member" parameters:
        'store_ncrna'   => 0,  # Store ncRNA genes
        'store_others'  => 0,  # Store other genes
    };
}

sub tweak_analyses {
    my $self = shift;
    $self->SUPER::tweak_analyses(@_);
    my $analyses_by_name = shift;

    # Block unguarded funnel analyses; to be unblocked as needed during pipeline execution.
    my @unguarded_funnel_analyses = (
        'offset_tables',
        'load_all_genomedbs_from_registry',
        'create_reuse_ss',
        'polyploid_genome_reuse_factory',
        'polyploid_genome_load_fresh_factory',
        'nonpolyploid_genome_load_fresh_factory',
        'hc_members_globally',
    );

    foreach my $logic_name (@unguarded_funnel_analyses) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }

}


1;
