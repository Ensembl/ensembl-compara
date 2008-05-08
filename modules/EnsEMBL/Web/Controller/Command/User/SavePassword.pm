package EnsEMBL::Web::Controller::Command::User::SavePassword;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::Invite;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = new CGI;
  if ($cgi->param('code')) {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::ActivationValid');
  }
  else {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordValid');
  }
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordSecure');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process;
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  my $user = EnsEMBL::Web::Data::User->new({ email => $cgi->param('email') });

  $user->password( EnsEMBL::Web::Tools::Encryption::encryptPassword($cgi->param('new_password_1')) );
  $user->status('active');
  $user->modified_by($user->id);
  $user->save;

  ## Add membership if coming from invitation acceptance
  if ($cgi->param('record_id')) {
    my $invitation = EnsEMBL::Web::Data::Invite->new({ id => $cgi->param('record_id') });
    my $membership = EnsEMBL::Web::Data::Membership->new;
    $membership->webgroup_id($invitation->webgroup_id);
    $membership->user_id($user->id);
    $membership->level('member');
    $membership->member_status('active');
    
    my $success = $membership->save;
    $invitation->destroy 
      if $success;
  }
  my $url = '/common/user/set_cookie?email='.$user->email
                  .';password='.$cgi->param('new_password_1')
                  .';url='.$cgi->param('url')
                  .';updated=yes';
  $url .= ';record_id='.$cgi->param('record_id') if $cgi->param('record_id'); 

  $cgi->redirect($url);
}

}

1;
