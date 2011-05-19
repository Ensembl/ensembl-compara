# $Id$

package EnsEMBL::Web::Component::Export::Configure;

use strict;

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $hub->get_viewconfig('Export', $hub->function);
  
  $view_config->build_form($self->object);
  
  my $form = $view_config->get_form;
  
  $form->set_attribute('method', 'post');
  
  return '<h2>Export Configuration - Feature List</h2>' . $form->render;
}

1;
