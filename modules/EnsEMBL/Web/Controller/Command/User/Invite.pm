package EnsEMBL::Web::Controller::Command::User::Invite;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Invite;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('id')});
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
  my $cgi = new CGI;
  my $url = "/common/user/view_group?id=" . $cgi->param('id');

  my $group = EnsEMBL::Web::Data::Group->new({ 'id' => $cgi->param('id') });
  my @addresses = split(/,/, $cgi->param('invite_email'));
  my %invite_check;
  foreach my $email (@addresses) {
    $email =~ s/ //g;

    ## Check pending invitations
    my @invites = @{ $group->invites };
    my $invited = 0;
    foreach my $invite (@invites) {
      if ($invite->email eq $email && $invite->status eq 'pending') {
        $invite_check{$email} = 'invited';
        $invited = 1;
        last;
      }
    }
    next if $invited;

    ## Is this user already a member?
    my $user = EnsEMBL::Web::Data::User->new({ email => $email });
    if ($user && $user->id) {
      my $member = $group->find_user_by_user_id($user->id);
      if ($member) {
        $invite_check{$email} = $member->member_status;
      }
      else {
        &send_invitation($cgi->param('id'), $email);
        $invite_check{$email} = 'exists';
      }
    }
    else {
      &send_invitation($cgi->param('id'), $email);
      $invite_check{$email} = 'new';
    }
  }
  my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'user/invite',
    'objecttype' => 'User',
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      #$object->invitees(\%invite_check);
      $webpage->configure( $object, 'invitations' );
    }
    $webpage->action();
  }

}

sub send_invitation {
  my ($group_id, $email) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $group = EnsEMBL::Web::Data::Group->new({ id => $group_id });

  my $invite = EnsEMBL::Web::Data::Invite->new;
  $invite->webgroup_id($group_id);
  $invite->email($email);
  $invite->status("pending");
  $invite->code(EnsEMBL::Web::Tools::RandomString::random_string());
  $invite->save;
  my $mailer = EnsEMBL::Web::Mailer::User->new;
  $mailer->send_invite_email($user, $group, $invite, $email);
}

}

1;
