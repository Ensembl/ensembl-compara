package EnsEMBL::Web::ZMenu::Gene::RNASeq;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  $self->SUPER::content;
  
  $self->caption($object->stable_id);

  #change label for gene type
  $self->modify_entry_by('type',{
    type  => 'Gene type',
    label => $object->Obj->biotype,
  });
}

1;
