package EnsEMBL::Web::Mailer::User;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Mailer;

our @ISA = qw(EnsEMBL::Web::Mailer);

{

#sub new {
#  ### c
#  my ($class, %params) = @_;
#  my $self = $class->SUPER::new(%params);
#  return $self;
#}

sub send_activation_email {
  ### Sends an activation email to newly registered users.
  my ($self, %params) = @_;

  my $group_id = $params{'group_id'};
  my $link = $params{'link'};
  my $code = $params{'code'};
  my $sitename = $self->site_name;

  my $message = qq(
Welcome to $sitename,

Thanks for registering with $sitename.

You just need to activate your account, using the link below:
);

  $message .= $self->activation_link($link);

  if ($group_id) {
    $message .= "&group_id=" . $group_id;
  }
  $message .= qq(

You activation code is: $code

);
  $message .= $self->email_footer;
  $self->subject("Your new $sitename account");
  $self->message($message);
  $self->send();
}

sub send_welcome_email {
  ### Sends a welcome email to newly registered users.
  my ($self, $email) = @_;
  my $sitename = $self->site_name;
  my $message = qq(Welcome to $sitename.

  Your account has been activated! In future, you can log in to $sitename using your email address and the password you chose during registration:

  Email: ) . $email . qq(

  More information on how to make the most of your account can be found here:

  ) . $self->base_url . qq(/info/about/accounts.html

);
  $message .= $self->email_footer;
  $self->subject("Welcome to $sitename");
  $self->message($message);
  $self->send();
}

sub send_invite_email {
  my ($self, $user, $group, $invite, $email) = @_;
  my $sitename = $self->site_name;
  my $message = qq(Hello,

 You have been invited by ) . $user->name . qq( to join a group
 on the ). $SiteDefs::ENSEMBL_SITETYPE. qq( Genome Browser.

 To accept this invitation, click on the following link:

 ) . $group->name . qq( 
 ) . $self->base_url . qq(/common/accept?id=) . $invite->id . qq(
 
 Your activation code is: ) . $invite->code . qq(

 If you do not wish to accept, please just disregard this email.

 Note: When accepting, please leave the user-code box blank.

 If you have any problems please don't hesitate to contact ) . $user->name . qq( 
 or the ) . $SiteDefs::ENSEMBL_SITETYPE . qq( help desk, on ) . 
 $SiteDefs::ENSEMBL_HELPDESK_EMAIL;

  $message .= $self->email_footer;
  $self->email($email);
  $self->subject("Invite to join a $SiteDefs::ENSEMBL_SITETYPE group");
  $self->message($message);
  $self->send();
}

sub send_reactivation_email {
  my ($self, $user) = @_;
  my $sitename = $self->site_name;
  my $message = qq(
Hello ) . $user->name . qq(,

We have received a request to change your $SiteDefs::ENSEMBL_SITETYPE account password. If you
submitted this request, click on the link below to update your password. If
not, please disregard this email.

);

  $message .= $self->activation_link('user_id=' . $user->id . "&code=" . $user->salt);

  $message .= $self->email_footer;
  $self->subject("Your $sitename account");
  $self->message($message);
  $self->send;
}

sub activation_link {
  my ($self, $link) = @_;
  my $return_link = $self->base_url . '/common/user/activate?' . $link;
  return $return_link;
}

sub email_footer {
  my ($self) = @_;
  my $site_info = shift;
  my $sitename = $self->site_name;
  my $footer = qq(

Many thanks,

The $sitename web team

$sitename Privacy Statement: ) . $self->base_url . qq(/info/about/privacy.html
);
  return $footer;
}

}

1;
