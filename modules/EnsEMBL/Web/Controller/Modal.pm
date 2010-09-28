# $Id$

package EnsEMBL::Web::Controller::Modal;

use strict;

use base qw(EnsEMBL::Web::Controller::Page);

sub page_type { return 'Popup'; }
sub request   { return 'modal'; }

sub init {
  my $self = shift;
  
  $self->builder->create_objects;
  $self->renderer->{'_modal_dialog_'} = $self->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; # Flag indicating that this is modal dialog panel, loaded by AJAX
  $self->page->initialize; # Adds the components to be rendered to the page module
  $self->configure;
  $self->render_page;
}

1;
