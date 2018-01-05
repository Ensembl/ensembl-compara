
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Synteny::DeleteSynteny

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::DeleteSynteny;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
  return {
    mlss_id                => undef,
  }
}

sub fetch_input {
    my $self = shift;

    $self->param_required('synteny_mlss_id');
    $self->param_required('mlss_id');
    $self->param('avg_genomic_coverage');
    $self->param('master_dba', $self->get_cached_compara_dba('master_db'));
    # Trick to elevate the privileges on this session only
    $self->elevate_privileges($self->param('master_dba')->dbc);
}


sub run {
    my $self = shift;
    my $mlss_tag_value = ($self->param('avg_genomic_coverage') ) ? $self->param('avg_genomic_coverage') : 'not_recorded';
    # Delete data from this database
    $self->compara_dba->dbc->db_handle->do('DELETE dnafrag_region FROM dnafrag_region JOIN synteny_region USING (synteny_region_id) WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->compara_dba->dbc->db_handle->do('DELETE FROM synteny_region WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->compara_dba->dbc->db_handle->do('DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    $self->compara_dba->dbc->db_handle->do('DELETE FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));

    # And the mlss entry in the master database
    $self->param('master_dba')->dbc->db_handle->do('DELETE FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $self->param('synteny_mlss_id'));
    # But also register in the master database that this pair of species is a lost cause
    $self->param('master_dba')->dbc->db_handle->do('INSERT INTO method_link_species_set_tag VALUES (?, "low_synteny_coverage", ?)', undef, $self->param('mlss_id'), $mlss_tag_value);

}


1;
