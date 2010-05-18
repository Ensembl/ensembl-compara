package EnsEMBL::Web::Component::Interface::Edit;

### Module to create generic data modification form for Document::Interface and its associated modules

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Interface);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
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
  my $form = $self->record_form($framework);
  return $form->render;
}

1;
