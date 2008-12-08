package EnsEMBL::Web::Controller::Command::Account::SendInvitation;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('id')});
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my %params = (
    'id'   => $cgi->param('id'),
    '_referer'  => $cgi->param('_referer'),
  );
 
  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('id'));
  my @addresses = split(/[,\s]+/, $cgi->param('emails'));
  my (@active, @pending);
  foreach my $email (@addresses) {
    $email =~ s/ //g;
    next unless $email =~ /^[^@]+@[^@.:]+[:.][^@]+$/;

    ## Check pending invitations
    my @invites = $group->invites;
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
  
  $self->ajax_redirect($self->url('/Account/ManageGroup', \%params));
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
  $mailer->send_invitation_email($group, $invite);
}

}

1;
