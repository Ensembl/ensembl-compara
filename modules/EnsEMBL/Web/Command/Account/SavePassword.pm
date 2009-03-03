package EnsEMBL::Web::Command::Account::SavePassword;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));

  $user->password( EnsEMBL::Web::Tools::Encryption::encryptPassword($object->param('new_password_1')) );
  $user->status('active');
  $user->modified_by($user->id);
  $user->save;

  my $param = {
    'email'     => $user->email,
    'password'  => $object->param('new_password_1'),
    'url'       => $object->param('url'),
    'updated'   => 'yes',
  };

  ## Account activation needs to go to the home page, not the control panel
  if ($object->param('code')) {
    $param->{'activated'} = 'yes';
  } 

  $self->ajax_redirect('/Account/SetCookie', $param);
}

}

1;
