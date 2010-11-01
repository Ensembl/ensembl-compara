package EnsEMBL::Web::Command::Account::AcceptInvitation;

use strict;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Record::Invite;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($hub->param('id'));
  my $url;

  if ($invitation->status eq 'pending') {
    $invitation->status('accepted');
    $invitation->save;

    ## Is this an existing user?
    my $existing_user = EnsEMBL::Web::Data::User->find('email' => $invitation->email);
    
    if ($existing_user) {
      ## Is the user already logged in?
      if ($hub->user) {
        my $group_id = $invitation->webgroup_id; ## Grab this *before* we destroy the invitation!
        $existing_user->update_invitations;
        $url = $self->url('/Account/MemberGroups', { id => $group_id, popup => 'no' });
      } else {
        ## Encourage user to log in
        $url = $self->url('/Account/Login', { email => $invitation->email, popup => 'no' });
      }
    } else {
      ## New user, so go to registration
      $url = $self->url('/Account/User/Add', { email => $invitation->email, popup => 'no' });
    }
  }
  $hub->redirect($url);
}

1;
