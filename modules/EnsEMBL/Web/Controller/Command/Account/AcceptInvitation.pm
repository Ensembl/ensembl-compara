package EnsEMBL::Web::Controller::Command::Account::AcceptInvitation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Invite;
use EnsEMBL::Web::Data::Membership;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::InvitationValid');
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
  my $invitation = EnsEMBL::Web::Data::Invite->new($cgi->param('id'));
  my $url; 
  if ($invitation->status eq 'pending') {
    ## Is this an existing user?
    my $existing_user = EnsEMBL::Web::Data::User->find('email' => $invitation->email);
    if ($existing_user) {
      ## Create membership link between user and group
      my $success = $self->add_member_from_invitation($existing_user, $invitation);
      if ($ENV{'ENSEMBL_USER_ID'}) {
        if ($success) {
          $invitation->destroy;
        }
        $url = $self->url('/Account/Group', {'id' => $invitation->webgroup_id} );
      }
      else {
        ## Set invitation status to 'accepted' (don't delete in case login fails!)
        $invitation->status('accepted');
        $invitation->save;
        $url = $self->url('/Account/Login', {'url' => $url, 'record_id' => $invitation->id} );
      }
    }
    else {
      ## Set invitation status to 'accepted'
      $invitation->status('accepted');
      $invitation->save;
      $url = $self->url('/Account/Register', 
          {'email' => $invitation->email, 'status' => 'active', 'record_id' => $invitation->id} );
    }
    $cgi->redirect($url);
  }
  else {
     my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'Account/_accept',
    'objecttype' => 'Account',
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
