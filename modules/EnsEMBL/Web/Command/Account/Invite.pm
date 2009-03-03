package EnsEMBL::Web::Command::Account::Invite;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my %params = (
    'id'   => $object->param('id'),
  );
 
  my $group = EnsEMBL::Web::Data::Group->new($object->param('id'));
  my @invites = $group->invites;
  my (@active, @pending);

  my @addresses = split(/[,\s]+/, $object->param('emails'));
  foreach my $email (@addresses) {
    $email =~ s/ //g;
    next unless $email =~ /^[^@]+@[^@.:]+[:.][^@]+$/;

    ## Check pending invitations
    my $invited = 0;
    foreach my $invite (@invites) {
      if ($invite->email eq $email && $invite->status eq 'pending') {
        push @pending, $email;
        $invited = 1;
        last;
      }
    }
    next if $invited;

    my $details = {email => $email, registered => 'N'};

    ## Is this user already a member?
    my $user = EnsEMBL::Web::Data::User->find(email => $email);
    if ($user) {
      my $member = $group->find_user_by_user_id($user->id);
      if ($member) {
        if  ($member->member_status eq 'active') {
          push @active, $email;
        }
        elsif ($member->member_status eq 'inactive') {
          $details->{'registered'} = 'Y';
          $self->_send_invitation($group, $details);
        }
      }
      else {
        $details->{'registered'} = 'Y';
        $self->_send_invitation($group, $details);
      }
    }
    else {
      $self->_send_invitation($group, $details);
    }
  }
  if (scalar(@active)) {
    $params{'active'} = \@active;
  }
  if (scalar(@pending)) {
    $params{'pending'} = \@pending;
  }
  
  $self->ajax_redirect('/Account/ManageGroup', \%params);
}

sub _send_invitation {
  my ($self, $group, $details) = @_;

  my $invite = $group->add_to_invites({
    email  => $details->{'email'},
    status => 'pending',
    registered => $details->{'registered'},
    code   => EnsEMBL::Web::Tools::RandomString::random_string(),
  });
  
  my $mailer = EnsEMBL::Web::Mailer::User->new;
  $mailer->send_invitation_email($self->object, $group, $invite);
}

}

1;
