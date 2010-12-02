# $Id$

package EnsEMBL::Web::Component::Export::Configure;

use strict;

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $hub->get_viewconfig($hub->function, 'Export');
  
  $view_config->build_form($self->object, 1);
  
  return '<h2>Export Configuration - Feature List</h2>' . $view_config->get_form->render;
}

1;
