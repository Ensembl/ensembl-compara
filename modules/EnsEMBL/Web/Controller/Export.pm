# $Id$

package EnsEMBL::Web::Controller::Export;

use strict;

use base qw(EnsEMBL::Web::Controller::Page);
 
sub page_type { return $_[0]->action eq 'Output' ? 'Dynamic' : 'Popup'; }
sub request   { return $_[0]->action eq 'Output' ? 'Export'  : 'Modal'; }

sub init {
  my $self = shift;
  
  $self->hub->type = $self->hub->function if $self->hub->action eq 'Output';    #this is to get the left nav and top nav according to the right object
  $self->builder->create_objects('Export');
  $self->renderer->{'_modal_dialog_'} = $self->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; # Flag indicating that this is modal dialog panel, loaded by AJAX
  $self->page->initialize; # Adds the components to be rendered to the page module  
  $self->configure;
  $self->page->remove_body_element('summary');
  $self->render_page;  
}

1;