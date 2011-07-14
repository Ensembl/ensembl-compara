package EnsEMBL::Web::Command::Account::SavePassword;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Tools::Encryption qw(encryptPassword);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));

  my $error = 0;
  my $message;
  my $new_password = $object->param('new_password_1');
  if ($new_password ne $object->param('new_password_2')) {
    $message = 'password_not_confirmed';
    $error   = 1;
  }
  elsif ($new_password !~ /^\S{6,32}$/) {
    $message = 'invalid_password';
    $error   = 1;
  }
  else {
    $user->password(encryptPassword($new_password));
    $user->status('active');
    $user->modified_by($user->id);
    $user->save;
    $message = 'password_saved';
  }
  
  if ($object->param('code')) { # if password reset after "password lost" request
    $self->ajax_redirect('/Account/SetCookie', {
      'email'     => $user->email,
      'password'  => $object->param('new_password_1') || '',
      'url'       => $object->param('url') || '',
      'activated' => 'yes',
      'updated'   => 'yes',
    });
  }

  else {  # if password changed
    my $params = { 'error' => $error, 'message' => $message };
    $params->{'back'} = $object->param('backlink') if $error && $object->param('backlink');
    $self->ajax_redirect('/Account/Message', $params);
  }
}

1;
