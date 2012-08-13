package EnsEMBL::Web::ZMenu::Transcript::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $object      = $self->object;
  my $gene        = $object->gene;
  my $gene_id     = $gene->stable_id;
  my $transcript  = $object->Obj;
  my $translation = $transcript->translation;
  $self->caption($gene_id);

  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $gene_id,
    link     => $self->hub->get_ExtURL_link($gene_id, 'REFSEQ_GENEIMP', $gene_id),
    extra    => { abs_url => 1 },
    position => 2,
  });

  my $biotype = ucfirst lc $gene->biotype;
  $biotype    =~ s/_/ /;
  $biotype    =~ s/rna/RNA/;

  $self->modify_entry_by('type',{
    type  => 'Gene type',
    label => $biotype,
  });

  if ($translation) {
    $self->delete_entry_by_type('Protein');
    my $stable_id = $translation->stable_id;
    $self->add_entry({
      type     => 'RefSeq protein',
      label    => $stable_id,
      link     => $self->hub->get_ExtURL_link($stable_id, 'REFSEQ_PROTIMP', $stable_id),
      extra    => { abs_url => 1 },
      position => 3
    });
  }

  $self->delete_entry_by_type('Gene');
  $self->delete_entry_by_type('Transcript');
}

1;
