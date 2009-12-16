package EnsEMBL::Web::Component::UserData::;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new('', '', 'post');

  ## navigation elements
  $form->add_element( 'type' => 'Submit', 'value' => 'Next');

  return $form->render;
}

1;
