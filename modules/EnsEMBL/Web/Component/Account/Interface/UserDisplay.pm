package EnsEMBL::Web::Component::Account::Interface::UserDisplay;

### Module to display the user's account details

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $user = $object->user;
  return unless $user;
  $object->interface->data($user);

  my $url = '/'.$self->object->interface->script_name.'/Edit';
  my $form = EnsEMBL::Web::Form->new('display', $url, 'post');

  my $preview_fields = $object->interface->preview_fields($user->id, $object);
  my $element;
  foreach my $element (@$preview_fields) {
    $form->add_element(%$element);
  }

  $form->add_element( 'type' => 'Submit', 'value' => 'Edit');

  return $form->render;
}

1;
