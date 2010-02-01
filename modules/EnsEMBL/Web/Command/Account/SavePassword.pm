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

  $user->password(encryptPassword($object->param('new_password_1')));
  $user->status('active');
  $user->modified_by($user->id);
  $user->save;

  my $param = {
    'email'     => $user->email,
    'password'  => $object->param('new_password_1'),
    'url'       => $object->param('url'),
    'updated'   => 'yes',
  };

  ## Password change is already logged in, so stay in control panel 
  my $new_url;
  if ($object->param('code')) {
    $new_url = '/Account/SetCookie';
    $param->{'activated'} = 'yes';
  } 
  else {
    $new_url = '/Account/QuickLinks';
  }

  $self->ajax_redirect($new_url, $param);
}

1;
