package EnsEMBL::Web::Command::Account::AcceptInvitation;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Record::Invite;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($object->param('id'));
  my $url;

  if ($invitation->status eq 'pending') {
    $invitation->status('accepted');
    $invitation->save;

    ## Is this an existing user?
    my $existing_user = EnsEMBL::Web::Data::User->find('email' => $invitation->email);
    if ($existing_user) {
      ## Is the user already logged in?
      if ($ENV{'ENSEMBL_USER_ID'}) {
        my $group_id = $invitation->webgroup_id; ## Grab this *before* we destroy the invitation!
        $existing_user->update_invitations;
        $url = $self->url('/Account/MemberGroups', {'id' => $group_id, 'popup' => 'no'} );
      }
      else {
        ## Encourage user to log in
        $url = $self->url('/Account/Login', {'email' => $invitation->email, 'popup' => 'no'} );
      }
    }
    else {
      ## New user, so go to registration
      $url = $self->url('/Account/User/Add', {'email' => $invitation->email, 'popup' => 'no'} );
    }
  }
  $object->redirect($url);
}

}

1;
