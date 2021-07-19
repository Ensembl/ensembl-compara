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

package EnsEMBL::Web::ZMenu::Transcript::RNASeq;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;

  $self->SUPER::content;

  my $object     = $self->object;
  my $transcript = $object->Obj;
  my $caption    = $object->stable_id;

  $self->caption($caption);

  # change label for gene type
  my $label = $transcript->biotype;
  $label =~ s/_/ /g;
  $self->modify_entry_by('type',{
    type  => 'Gene type',
    label => ucfirst($label),
  });

  $self->add_entry({
    type  => 'Evidence',
    label => $caption,
    link  => $self->hub->url({
      type     => 'Transcript',
      action   => 'SupportingEvidence',
      }),
    position => 1,
  });

  # add new entries for attributes
  foreach my $attrib (@{$transcript->get_all_Attributes('AltThreePrime') || []}) {
    $self->add_entry({
      type  => $attrib->{'name'},
      label => $attrib->{'value'},
    });
  }

  $self->delete_entry_by_type('Protein');
  $self->delete_entry_by_type('Exon');
  $self->delete_entry_by_value($object->gene->stable_id);
  my $loc = sprintf(
    '%s: %s-%s',
    $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
    $self->thousandify($object->seq_region_start),
    $self->thousandify($object->seq_region_end)
  );
  $self->delete_entry_by_value($loc);
  $self->delete_entry_by_value($object->gene_stat_and_biotype);
  if (my $translation = $transcript->translation) {
    $self->delete_entry_by_value($self->thousandify($translation->length));
  }

  # delete unwanted entry and then re-add - adds it to the bottom of the zmenu
  $self->delete_entry_by_value($object->analysis->description);
  $self->add_entry({
    label_html => $object->analysis->description
  });

  $self->delete_entry_by_value('Exons');
  $self->delete_entry_by_value('cDNA Sequence');
  $self->delete_entry_by_value('Protein Variations');

}

1;
