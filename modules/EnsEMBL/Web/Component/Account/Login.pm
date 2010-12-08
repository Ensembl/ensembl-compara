package EnsEMBL::Web::Component::Account::Login;

### Module to create user login form 

use strict;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Login';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Control panel fixes
  my $dir = $object->species_path;
  
  my $form = $self->new_form({
    'id'      => 'login',
    'action'  => "$dir/Account/SetCookie",
  });

  my $fieldset = $form->add_fieldset;

  $fieldset->add_hidden([
    {'name'  => 'url', 'value' => $object->param('url')},
    {'name'  => 'popup', 'value' => $object->param('popup')}
  ]);

  $fieldset->add_field([
    {'type'  => 'Email',    'name'  => 'email',     'label' => 'Email',     'required' => 'yes'},
    {'type'  => 'Password', 'name'  => 'password',  'label' => 'Password',  'required' => 'yes'},
    {'type'  => 'Submit',   'name'  => 'submit',    'value' => 'Log in',    'class' => 'cp-refresh'}
  ]);

  my $reg_url = $self->url("$dir/Account/User/Add");
  my $pwd_url = $self->url("$dir/Account/LostPassword");

  $fieldset->add_notes(qq(<p><a href="$reg_url" class="modal_link">Register</a>
                                  | <a href="$pwd_url" class="modal_link">Lost password</a></p>));

  return $form->render;
}

1;
