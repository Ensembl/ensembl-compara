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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::PigBreedsEPOwithExt_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::PigBreedsEPOwithExt_conf.pm \
        -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

    Selected funnel analyses are blocked on pipeline initialisation.
    These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::PigBreedsEPOwithExt_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EPOwithExt_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},

        'division'               => 'vertebrates',
        'linked_mlss_unreleased' => 1,
        'method_type'            => 'EPO_EXTENDED',
        'species_set_name'       => 'pig_breeds',
    };
}

sub tweak_analyses {
    my $self = shift;
    $self->SUPER::tweak_analyses(@_);
    my $analyses_by_name = shift;

    # Block unguarded funnel analyses; to be unblocked as needed during pipeline execution.
    my @unguarded_funnel_analyses = (
        'reuse_anchor_align_factory',
        'offset_tables',
        'map_anchor_align_genome_factory',
        'mlss_factory',
        'remove_overlaps',
        'missing_anchors_factory',
        'set_gerp_mlss_tag',
        'setup_extended_alignment',
        'update_max_alignment_length',
        'multiplealigner_stats_factory',
    );

    foreach my $logic_name (@unguarded_funnel_analyses) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }

}

1;
