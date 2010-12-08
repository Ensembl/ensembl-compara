package EnsEMBL::Web::Component::Account::Password;

### Module to create password entry/update form 

use strict;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form;
  my $fieldset;

  # Use different destination, so we can apply different access filters
  if ($object->param('code')) {
    $form     = $self->new_form({'id' => 'enter_password', 'action' => '/Account/SavePassword'});
    $fieldset = $form->add_fieldset('Activate your account');
  } else {
    $form     = $self->new_form({'id' => 'enter_password', 'action' => '/Account/ResetPassword'});
    $fieldset = $form->add_fieldset('Change your password');
    $fieldset->add_field({'type' => 'Password', 'name' => 'password', 'label' => 'Old password', 'required' => 'yes'});
  }

  # Logged-in user, changing own password
  if (my $user = $object->user) {
    my $email = $user->email;
    my $species = $object->species;
    $species = '' if $species !~ /_/;

    $fieldset->add_hidden([
      {'name' => 'email', 'value' => $email},
      {'name' => 'cp_species', 'value' => $species}
    ]);
  } else {
    # Setting new/forgotten password
    $fieldset->add_hidden([
      {'name' => 'user_id', 'value' => $object->param('user_id')},
      {'name' => 'email',   'value' => $object->param('email')},
      {'name' => 'code',    'value' => $object->param('code')}
    ]);
  }

  $fieldset->add_hidden({'name'  => 'record_id', 'value' => $object->param('record_id')}) if $object->param('record_id');

  $fieldset->add_field([
    {'type' => 'password', 'name' => 'new_password_1', 'label' => 'New password',         'required' => 'yes'},
    {'type' => 'password', 'name' => 'new_password_2', 'label' => 'Confirm new password', 'required' => 'yes'},
    {'type' => 'submit',   'name' => 'submit',         'value' => 'Save',                 'class' => 'modal_link'}
  ]);

  $fieldset->add_hidden({'name' => 'backlink', 'value' => $self->hub->action});

  return $form->render;
}

1;
