=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Transcript::CCDS;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $object    = $self->object;
  my $stable_id = $object->stable_id;
  
  $self->caption($object->gene->stable_id);
  
  $self->add_entry({
    type     => 'CCDS',
    label    => $stable_id,
    link     => $self->hub->get_ExtURL_link($stable_id, 'CCDS', $stable_id),
    abs_url  => 1,
    position => 1,
  });
  
  $self->delete_entry_by_type($_) for ('Transcript', 'Protein', 'Gene type', 'Gene', 'Exon');
  $self->delete_entry_by_value('cDNA Sequence');
  $self->delete_entry_by_value('Exons');
  $self->delete_entry_by_value('Protein Variations');
}

1;
