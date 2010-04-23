package EnsEMBL::Web::ZMenu::Gene::RNASeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {

  my $self = shift;
  $self->SUPER::content;
  my $object  = $self->object;
  $self->caption($object->gene->stable_id);

  #change label for gene type
  $self->modify_entry_by_type({
    type  => 'Gene type',
    label => $object->gene->biotype,
  });
}

1;
