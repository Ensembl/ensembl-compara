package EnsEMBL::Web::ZMenu::Gene::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self = shift;
  $self->SUPER::content;
  my $object = $self->object;
  $self->caption($object->stable_id);

  if ($object->gene) {
    $self->add_entry({
      type  => 'RefSeq gene',
      label => $object->stable_id,
      link  => $object->get_ExtURL_link($object->gene->stable_id,'REFSEQ_GENEIMP',$object->gene->stable_id ),
      extra => { abs_url => 1 },
      position => 2,
    });
  }

  my $biotype = ucfirst(lc $object->gene->biotype);
  $biotype =~ s/_/ /;
  $biotype =~ s/rna/RNA/;
  $self->modify_entry_by_type({
    type  => 'Gene type',
    label => $biotype,
  });

}

1;
