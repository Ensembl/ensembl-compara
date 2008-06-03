package EnsEMBL::Web::Component::User::Login;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::User);
use EnsEMBL::Web::Form;

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

  my $form = EnsEMBL::Web::Form->new( 'login', "/User/_set_cookie", 'post' );
  my $reg_url = $self->url('/User/Register');
  my $pwd_url = $self->url('/User/LostPassword');

  $form->add_element('type'  => 'String', 'name'  => 'email', 'label' => 'Email', 'required' => 'yes');
  $form->add_element('type'  => 'Password', 'name'  => 'password', 'label' => 'Password', 'required' => 'yes');
  $form->add_element('type'  => 'Hidden', 'name'  => 'url', 'value' => $self->object->param('url'));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Log in');
  $form->add_element('type'  => 'Information',
                     'value' => qq(<p><a href="$reg_url">Register</a>
                                  | <a href="$pwd_url">Lost password</a></p>));

  return $form->render;
}

1;
