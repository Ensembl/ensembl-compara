=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Transcript::RefSeq;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $gene        = $object->gene;
  my $gene_id     = $gene->stable_id;
  my $translation = $object->Obj->translation;
  
  $self->caption($gene_id);

  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $gene_id,
    link     => $hub->get_ExtURL_link($gene_id, 'REFSEQ_GENEIMP', $gene_id),
    abs_url  => 1,
    position => 1,
  });

  my $biotype = ucfirst lc $gene->biotype;
     $biotype =~ s/_/ /;
     $biotype =~ s/rna/RNA/;

  $self->modify_entry_by('type', {
    type  => 'Gene type',
    label => $biotype,
  });

  if ($translation) {
    my $translation_id = $translation->stable_id;
    
    $self->delete_entry_by_type('Protein');
    
    $self->add_entry({
      type     => 'RefSeq protein',
      label    => $translation_id,
      link     => $hub->get_ExtURL_link($translation_id, 'REFSEQ_PROTIMP', $translation_id),
      abs_url  => 1,
      position => 2
    });
  }

  $self->delete_entry_by_type('Gene');
  $self->delete_entry_by_type('Transcript');
  $self->delete_entry_by_type('Exons');
  $self->delete_entry_by_type('Exon');
  $self->delete_entry_by_value('cDNA Sequence');
  $self->delete_entry_by_value('Protein Variations');

}

1;
