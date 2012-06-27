package EnsEMBL::Web::ZMenu::Gene::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self      = shift;
  my $object    = $self->object;
  my $stable_id = $object->stable_id;
  my $gene      = $object->Obj;
  
  $self->SUPER::content;
  
  $self->caption($stable_id);

  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $stable_id,
    link     => $self->hub->get_ExtURL_link($stable_id, 'REFSEQ_GENEIMP', $stable_id),
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

  $self->delete_entry_by_type('Gene');

}

1;
