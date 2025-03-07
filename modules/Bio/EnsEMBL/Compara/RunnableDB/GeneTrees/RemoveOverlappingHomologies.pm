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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies

=head1 DESCRIPTION

When we build the strains/breeds/cultivars gene trees we end up with two databases,
both having some shared homology MLSSs (e.g. rat vs mouse). The redundant homology MLSSs
and their corresponding tags/attributes in the strains/breeds/cultivars database have to
be removed.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $master_dba          = $self->get_cached_compara_dba('master_db');
    my $master_mlss_adaptor = $master_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss_id             = $self->param_required('mlss_id');

    my $mlss                = $master_mlss_adaptor->fetch_by_dbID($mlss_id);
    my $mlss_info           = $mlss->find_homology_mlss_sets();
    my @overlap_mlss_ids    = @{$mlss_info->{'overlap_mlss_ids'}};

    $self->param('overlapping_mlss_ids', \@overlap_mlss_ids);
}

sub run {
    my $self = shift;

    foreach my $mlss_id (@{$self->param('overlapping_mlss_ids')}) {
        warn "Going to remove ", $mlss_id, "\n" if $self->debug;
        $self->_remove_homologies($mlss_id);
    }
}

sub _remove_homologies {
    my ($self, $mlss_id) = @_;

    $self->compara_dba->dbc->do('DELETE homology_member FROM homology_member JOIN homology USING (homology_id) WHERE method_link_species_set_id = ?', undef, $mlss_id);
    $self->compara_dba->dbc->do('DELETE FROM homology WHERE method_link_species_set_id = ?',                                                          undef, $mlss_id);
    $self->compara_dba->dbc->do('DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = ?',                                       undef, $mlss_id);
    $self->compara_dba->dbc->do('DELETE FROM method_link_species_set_attr WHERE method_link_species_set_id = ?',                                      undef, $mlss_id);
}

1;
