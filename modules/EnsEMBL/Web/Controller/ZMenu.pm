# $Id$

package EnsEMBL::Web::Controller::ZMenu;

### Prints the popup zmenus on the images.

use strict;

use base qw(EnsEMBL::Web::Controller);

sub init {
  my $self = shift;
  
  $self->builder->create_objects;
  
  my $hub    = $self->hub;
  my $object = $self->object;
  my $module = $self->get_module_names('ZMenu', $self->type, $self->action);
  my $menu   = $module->new($hub, $object);
  
  $self->r->content_type('text/plain');
  $menu->render if $menu;
}

1;
