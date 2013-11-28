=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Transcript::LRG;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $transcript  = $object->Obj;
  my $translation = $transcript->translation;

  $self->caption('LRG Gene');

  $self->add_entry({
    type  => 'Gene type',
    label => $object->gene_stat_and_biotype
  });

  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });

  $self->add_entry({
    type  => 'Base pairs',
    label => $self->thousandify($transcript->seq->length)
  });

  if ($translation) {
    $self->add_entry({
      type     => 'Protein',
      label    => $translation->stable_id || $object->stable_id,
      #link     => $self->hub->url({ type => 'Transcript', action => 'ProteinSummary' }), # no link for LRGs yet
      position => 3
    });

    $self->add_entry({
      type  => 'Amino acids',
      label => $self->thousandify($translation->length)
    });
  }

  $self->add_entry({
    label_html => $object->analysis->description
  });
}

1;
