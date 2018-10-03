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

Bio::EnsEMBL::Compara::RunnableDB::Synteny::UpdateMlssTag

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::UpdateMlssTag;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    $self->param_required('synteny_mlss_id');
    $self->param('master_dba', $self->get_cached_compara_dba('master_db'));
    # Trick to elevate the privileges on this session only
    $self->elevate_privileges($self->param('master_dba')->dbc);
}

sub run {
    my $self = shift;

    my ($source_mlss_id, $source_mlss_id_name);
    foreach my $s (qw(alignment_mlss_id orthologue_mlss_id)) {
        if ($source_mlss_id = $self->param($s)) {
            $source_mlss_id_name = $s;
            last;
        }
    }
    $self->compara_dba->dbc->db_handle->do('INSERT INTO method_link_species_set_tag VALUES (?, "synteny_mlss_id", ?)', undef, $source_mlss_id, $self->param('synteny_mlss_id') );
    $self->compara_dba->dbc->db_handle->do('INSERT INTO method_link_species_set_tag VALUES (?, ?, ?)', undef, $self->param('synteny_mlss_id'), $source_mlss_id_name, $source_mlss_id );
    $self->param('master_dba')->dbc->db_handle->do('INSERT INTO method_link_species_set_tag VALUES (?, "synteny_mlss_id", ?)', undef, $source_mlss_id, $self->param('synteny_mlss_id') );
    $self->param('master_dba')->dbc->db_handle->do('INSERT INTO method_link_species_set_tag VALUES (?, ?, ?)', undef, $self->param('synteny_mlss_id'), $source_mlss_id_name, $source_mlss_id );
}

1;

