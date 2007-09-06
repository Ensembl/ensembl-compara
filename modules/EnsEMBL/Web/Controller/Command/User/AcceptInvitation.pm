package EnsEMBL::Web::Controller::Command::User::AcceptInvitation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Object::Data::Invite;
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
  my $invitation = EnsEMBL::Web::Object::Data::Invite->new({'id' => $cgi->param('id')});
  my $url; 
  if ($invitation->status eq 'pending') {
    ## Is this an existing user?
    my $existing_user = EnsEMBL::Web::Object::User->new({'email' => $invitation->email, adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor});
    if ($existing_user) {
      ## Create membership link between user and group
      my $success = $self->add_member_from_invitation($existing_user, $invitation);
      if ($ENV{'ENSEMBL_USER_ID'}) {
        if ($success) {
          $invitation->destroy;
        }
        $url = '/common/user/view_group?id='.$invitation->webgroup_id;
      }
      else {
        ## Set invitation status to 'accepted' (don't delete in case login fails!)
        $invitation->status('accepted');
        $invitation->save;
        $url = '/common/user/login?url='.$cgi->escape($url).';record_id='.$invitation->id;
      }
    }
    else {
      ## Set invitation status to 'accepted'
      $invitation->status('accepted');
      $invitation->save;
      $url = '/common/user/register?email='.$invitation->email.';status=active;record_id='.$invitation->id;
    }
    $cgi->redirect($url);
  }
  else {
     my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'user/accept',
    'objecttype' => 'User',
      );

    if( $webpage->has_a_problem() ) {
      $webpage->render_error_page( $webpage->problem->[0] );
    } 
    else {
      foreach my $object( @{$webpage->dataObjects} ) {
        $object->param('status', $invitation->status);
        $webpage->configure( $object, 'invitation_nonpending' );
      }
      $webpage->action();
    }
  }
}

}

1;
