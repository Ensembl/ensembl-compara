package EnsEMBL::Web::Controller::Command::Account::SavePassword;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = $self->action->cgi; 
  if ($cgi->param('code')) {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::ActivationValid');
  }
  else {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordValid');
  }
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordSecure');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));

  $user->password( EnsEMBL::Web::Tools::Encryption::encryptPassword($cgi->param('new_password_1')) );
  $user->status('active');
  $user->modified_by($user->id);
  $user->save;

  ## Add membership if coming from invitation acceptance
  if ($cgi->param('record_id')) {
    my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($cgi->param('record_id'));
    my $group = EnsEMBL::Web::Data::Group->new($invitation->webgroup_id);

    $invitation->destroy
      if $group->add_user($user);
  }

  my $param = {
    'email'     => $user->email,
    'password'  => $cgi->param('new_password_1'),
    'url'       => $cgi->param('url'),
    'updated'   => 'yes',
    '_referer'  => $cgi->param('_referer'),
    'x_requested_with'  => $cgi->param('x_requested_with'),
  };
  if ($cgi->param('record_id')) {
    $param->{'record_id'} = $cgi->param('record_id');
  } 
  ## Account activation needs to go to the home page, not the control panel
  if ($cgi->param('code')) {
    $param->{'activated'} = 'yes';
  } 

  my $url = $self->url('Account/SetCookie', $param);
  if ($cgi->param('no_popup')) {
    $cgi->redirect($url);
  }
  else {
    $self->ajax_redirect($url);
  }
}

}

1;
