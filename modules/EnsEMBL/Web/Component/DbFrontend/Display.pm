package EnsEMBL::Web::Component::DbFrontend::Display;

### NAME: EnsEMBL::Web::Component::DbFrontend::Display
### Creates a page displaying a single record from the database

### STATUS: Under development
### Note: This module should not be modified! 
### To customise an individual form, see the appropriate 
### EnsEMBL::Web::Framework child module 

### DESCRIPTION:

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::DbFrontend);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
### Uses an action-less form to display a record neatly!
  my $self = shift;

  my $class = 'EnsEMBL::Web::Framework::'.$self->model->hub->action;
  my $framework;

  if ($self->dynamic_use($class)) {
    $framework = $class->new($self->model);
  }
  else {
    ## Fall back on a completely auto-generated interface
    $framework = EnsEMBL::Web::Framework->new($self->model);
  }
  my $form = $self->display_record($framework);
  return $form->render;

}

1;
