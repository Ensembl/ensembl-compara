package EnsEMBL::Web::ZMenu::Transcript::RefSeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  $self->SUPER::content;
  my $object = $self->object;
  $self->caption($object->gene->stable_id);

  $self->add_entry({
    type     => 'RefSeq gene',
    label    => $object->gene->stable_id,
    link     => $object->get_ExtURL_link($object->gene->stable_id,'REFSEQ_GENEIMP',$object->gene->stable_id ),
    extra    => { abs_url => 1 },
    position => 3,
    });

  my $biotype = ucfirst(lc $object->gene->biotype);
  $biotype =~ s/_/ /;
  $biotype =~ s/rna/RNA/;

  $self->modify_entry_by_type({
    type  => 'Gene type',
    label => $biotype,
  });

  $self->delete_entry_by_type('Transcript');
}

1;
