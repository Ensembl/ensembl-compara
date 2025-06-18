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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::LoadMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::LoadMembers_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the LoadMembers pipeline for Metazoa. Please, refer
to the parent class for further information.

Selected funnel analyses are blocked on pipeline initialisation.
These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::LoadMembers_conf;

use strict;
use warnings;

use File::Spec::Functions;

use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'  => 'metazoa',

        # Names of species we do not want to reuse this time
        # 'do_not_reuse_list' => [ 'oryza_indica', 'vitis_vinifera' ],
        'do_not_reuse_list' => [],

        # "Member" parameters:
        'store_ncrna'   => 0,  # Store ncRNA genes
        'store_others'  => 0,  # Store other genes
    };
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    $analyses_by_name->{'check_reusability'}->{'-parameters'}{'list_must_reuse_species_exe'} = $self->o('list_must_reuse_species_exe');
    $analyses_by_name->{'check_reusability'}->{'-parameters'}{'must_reuse_collection_file'} = catfile($self->o('config_dir'), 'must_reuse_collections.json');
    $analyses_by_name->{'check_reusability'}->{'-parameters'}{'mlss_conf_file'} = catfile($self->o('config_dir'), 'mlss_conf.xml');
    $analyses_by_name->{'check_reusability'}->{'-parameters'}{'ensembl_release'} = $self->o('ensembl_release');

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
