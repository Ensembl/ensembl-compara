package EnsEMBL::Web::Component::Export::Configure;

use strict;

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $vc = $object->get_viewconfig($object->function, 'Export');
  
  $vc->form($object, 1);
  
  return '<h2>Export Configuration - Feature List</h2>' . $vc->get_form->render;
}

1;
