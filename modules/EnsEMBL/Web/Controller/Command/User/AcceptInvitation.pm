package EnsEMBL::Web::Controller::Command::User::AcceptInvitation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Object::Data::Invitation;
use EnsEMBL::Web::Object::Data::Membership;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::InvitationValid');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  $self->filters->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message;
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;
  my $invitation = EnsEMBL::Web::Object::Data::Invitation->new({'id' => $cgi->param('id')});
  my $url = '/common/user/view_group?id='.$invitation->webgroup_id;
 
  if ($invitation->status eq 'pending') {
    ## Is this an existing user?
    my $existing_user = EnsEMBL::Web::Object::User->new({'email' => $invitation->email, adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor});
    if ($existing_user) {
      warn "USER: ", $existing_user->id;
      ## Create membership link between user and group
      my $membership = EnsEMBL::Web::Object::Data::Membership->new();
      $membership->webgroup_id($invitation->webgroup_id);
      $membership->user_id($existing_user->id);
      $membership->level('member');
      $membership->status('active');
      my $success = $membership->save;
      if ($success) {
        $invitation->destroy;
      }
      if (!$ENV{'ENSEMBL_USER_ID'}) {
        $url = '/common/user/login?url='.$cgi->escape($url);
      }
    }
    else {
      ## Set invitation status to 'accepted'
      $invitation->status('accepted');
      $invitation->save;
      $url = '/common/user/register?email='.$invitation->email.';status=active;record_id='.$invitation->id;
    }
  }
  $cgi->redirect($url);
}

}

1;
