# $Id$

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
    position => 2,
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
      position => 3
    });
  }

  $self->delete_entry_by_type('Gene');
  $self->delete_entry_by_type('Transcript');
}

1;
