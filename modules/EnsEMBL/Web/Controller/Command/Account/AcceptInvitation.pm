package EnsEMBL::Web::Controller::Command::Account::AcceptInvitation;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Record::Invite;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::InvitationValid');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($cgi->param('id'));
  my $url; 
  if ($invitation->status eq 'pending') {
    ## Is this an existing user?
    my $existing_user = EnsEMBL::Web::Data::User->find('email' => $invitation->email);
    if ($existing_user) {
      ## Create membership link between user and group
      my $success = $self->add_member_from_invitation($existing_user, $invitation);
      if ($ENV{'ENSEMBL_USER_ID'}) {
        my $group_id = $invitation->webgroup_id;
        if ($success) {
          $invitation->destroy;
        }
        $url = $self->url('/Account/MemberGroups', {'id' => $group_id, no_popup => 1} );
      }
      else {
        ## Set invitation status to 'accepted' (don't delete in case login fails!)
        $invitation->status('accepted');
        $invitation->save;
        $url = $self->url('/Account/Login', {'url' => $url, 'record_id' => $invitation->id, no_popup => 1} );
      }
    }
    else {
      ## Set invitation status to 'accepted'
      $invitation->status('accepted');
      $invitation->save;
      $url = $self->url('/Account/Register', 
          {'email' => $invitation->email, 'status' => 'active', 'record_id' => $invitation->id, no_popup => 1} );
    }
    $cgi->redirect($url);
  }
}

}

1;
