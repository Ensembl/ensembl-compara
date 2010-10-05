# $Id$

package EnsEMBL::Web::Component::Export::Configure;

use strict;

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  
  my $vc = $hub->get_viewconfig($hub->function, 'Export');
  
  $vc->form($self->object, 1);
  
  return '<h2>Export Configuration - Feature List</h2>' . $vc->get_form->render;
}

1;
