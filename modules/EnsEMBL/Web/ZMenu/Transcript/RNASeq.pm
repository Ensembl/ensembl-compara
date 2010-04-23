package EnsEMBL::Web::ZMenu::Transcript::RNASeq;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

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

  #add new entries for attributes
  foreach my $attrib (@{ $object->Obj->get_all_Attributes('AltThreePrime') || [] }) {
    $self->add_entry({
      type  => $attrib->{'description'},
      label => $attrib->{'value'},
    });
  }

  #delete unwanted entry and then re-add - adds it to the bottom of the zmenu
  $self->delete_entry_by_value($object->analysis->description);
  $self->add_entry({
      label_html => $object->analysis->description
    });
}

1;
