package EnsEMBL::Web::ZMenu::Transcript::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $gene    = $self->object->gene;
  my $gene_id = $gene->stable_id;
  
  $self->caption($gene_id);

  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $gene_id,
    link     => $self->hub->get_ExtURL_link($gene_id, 'REFSEQ_GENEIMP', $gene_id),
    extra    => { abs_url => 1 },
    position => 3,
  });

  my $biotype = ucfirst lc $gene->biotype;
  $biotype    =~ s/_/ /;
  $biotype    =~ s/rna/RNA/;

  $self->modify_entry_by_type({
    type  => 'Gene type',
    label => $biotype,
  });
  
  $self->delete_entry_by_type('Transcript');
}

1;
