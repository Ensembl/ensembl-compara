=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Idhistory::Node;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Idhistory);

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $a_id    = $hub->param('node') || die 'No node value in params';
  my $archive = $self->archive_adaptor->fetch_by_stable_id_dbname($a_id, $hub->param('db_name'));
  my $id      = $archive->stable_id . '.' . $archive->version;

  $self->caption($id);

  $self->add_entry({
    type       => $archive->type eq 'Translation' ? 'Protein' : $archive->type,
    label_html => $id,
    link       => $self->archive_link($archive)
  });
  
  $self->add_entry({
    type  => 'Release',
    label => $archive->release
  });
  
  $self->add_entry({
    type  => 'Assembly',
    label => $archive->assembly
  });
  
  $self->add_entry({
    type  => 'Database',
    label => $archive->db_name
  });
}

1;
