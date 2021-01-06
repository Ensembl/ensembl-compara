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

Bio::EnsEMBL::Compara::RunnableDB::Synteny::DeleteSynteny

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::DeleteSynteny;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $mlss_id = $self->param('ortholog_mlss_id') || $self->param('pairwise_mlss_id');
    $self->param('mlss_id', $mlss_id);

    $self->param_required('synteny_mlss_id');
    $self->param('avg_genomic_coverage');
    $self->param('master_dba', $self->get_cached_compara_dba('master_db'));
    $self->param('curr_release_dba', $self->get_cached_compara_dba('curr_release_db'));
    # Trick to elevate the privileges on this session only
    $self->elevate_privileges($self->param('master_dba')->dbc);
    $self->elevate_privileges($self->param('curr_release_dba')->dbc);
}


sub run {
    my $self = shift;
    my $mlss_tag_value = $self->param('avg_genomic_coverage') // '0';
    # Delete data from this database
    $self->compara_dba->dbc->do('DELETE dnafrag_region FROM dnafrag_region JOIN synteny_region USING (synteny_region_id) WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->compara_dba->dbc->do('DELETE FROM synteny_region WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->compara_dba->dbc->do('DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->compara_dba->dbc->do('DELETE FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));

    # And the mlss entry in the master database
    $self->param('master_dba')->dbc->do('DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->param('master_dba')->dbc->do('DELETE FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    # But also register in the master database that this pair of species is a lost cause
    $self->param('master_dba')->dbc->do('REPLACE INTO method_link_species_set_tag VALUES (?, "low_synteny_coverage", ?)', undef, $self->param('mlss_id'), $mlss_tag_value);

    # And the mlss entry in the release database because they would have been copied by copy data from master db earlier in the release
    $self->param('curr_release_dba')->dbc->do('DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->param('curr_release_dba')->dbc->do('DELETE FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->param('curr_release_dba')->dbc->do('REPLACE INTO method_link_species_set_tag SELECT method_link_species_set_id, "low_synteny_coverage", ? FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $mlss_tag_value, $self->param('mlss_id'));

}


1;
