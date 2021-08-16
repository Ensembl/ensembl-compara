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
  my $gene_xref   = $gene->display_xref && $gene->display_xref->primary_id;
  my $transcript_id      = $object->Obj->stable_id;
  my $transcript_xref    = $object->Obj->display_xref && $object->Obj->display_xref->primary_id;
  my $transcript_version = $object->Obj->version;
  my $transcript_link    = $transcript_version ? $transcript_id.'.'.$transcript_version : $transcript_id;
  my $translation = $object->Obj->translation;
 
  $gene_xref ||= $gene_id;
  $transcript_xref ||= $transcript_id;

  $self->caption($gene_xref);

  #remove standard links to gene pages and replace with one to NCBI
  $self->delete_entry_by_type('Gene');
  $self->delete_entry_by_value($gene_id);


  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $gene_xref,
    link     => $hub->get_ExtURL_link($gene_xref, 'REFSEQ_GENEIMP', $gene_xref),
    abs_url  => 1,
    position => 1,
  });

  my $biotype = lc $gene->biotype;
     $biotype =~ s/_/ /g;
     $biotype =~ s/rna/RNA/;

  $self->modify_entry_by('type', {
    type  => 'Gene type',
    label => $biotype,
  });

  #remove standard links to transcript pages and replace with one to NCBI
  $self->delete_entry_by_type('Transcript');
  $self->delete_entry_by_value($transcript_link);

  unless ($biotype =~ m/tRNA/ or $biotype =~ m/IG_/)
  {
    $self->add_entry({
      type     => 'RefSeq transcript',
      label    => $transcript_xref,
      link     => $hub->get_ExtURL_link($transcript_xref, 'REFSEQ_MRNA_PREDICTED', $transcript_xref),
      abs_url  => 1,
      position => 2,
    });
  }
 
  if ($translation) {
    my $translation_id = $translation->stable_id;
    $self->delete_entry_by_type('Protein');
    my $translation_xref =  $translation->get_all_DBEntries('GenBank')->[0]->primary_id || $translation_id;
    $self->add_entry({
      type     => 'RefSeq protein',
      label    => $translation_xref,
      link     => $hub->get_ExtURL_link($translation_xref, 'REFSEQ_PROTIMP', $translation_xref),
      abs_url  => 1,
      position => 3,
    });
  }

  $self->delete_entry_by_type('Exon');
  $self->delete_entry_by_value('Exons');
  $self->delete_entry_by_value('cDNA Sequence');
  $self->delete_entry_by_value('Protein Variations');
}

1;
