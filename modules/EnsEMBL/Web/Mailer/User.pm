package EnsEMBL::Web::Mailer::User;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Mailer);

{

sub send_activation_email {
  ### Sends an activation email to newly registered users.
  my ($self, %params) = @_;

  my $sitename  = $self->get_site_name;
  my $user      = $params{'user'};
  return unless $user;

  my $message;
  if ($params{'lost'}) {
    $self->set_subject("$sitename account reactivation");
    $message = qq(
Hello ) . $user->name . qq(,

We have received a request to reactivate your Ensembl account. If you
submitted this request, click on the link below to update your password. If
not, please disregard this email.

);
  }
  else {
    $self->set_subject("Your new $sitename account");
    $message = qq(
Welcome to $sitename,

Thanks for registering with $sitename.

You just need to activate your account, using the link below:
);
  }

  $message .= $self->get_baseurl.'/Account/Activate?email='.$user->email.';code='.$user->salt;

  if ($params{'group_id'}) {
    $message .= ";group_id=" . $params{'group_id'};
  }
  if ($params{'record_id'}) {
    $message .= ";record_id=" . $params{'record_id'};
  }

  $message .= $self->email_footer;
  $self->set_message($message);
  $self->send;
}

sub send_welcome_email {
  ### Sends a welcome email to newly registered users.
  my ($self, $email) = @_;
  my $sitename = $self->get_site_name;
  my $message = qq(Welcome to $sitename.

  Your account has been activated! In future, you can log in to $sitename using your email address and the password you chose during registration:

  Email: ) . $email . qq(

  More information on how to make the most of your account can be found here:

  ) . $self->get_baseurl . qq(/info/about/accounts.html

);
  $message .= $self->email_footer;
  $self->set_subject("Welcome to $sitename");
  $self->set_message($message);
  $self->send();
}

sub send_invitation_email {
  my ($self, $group, $invite) = @_;
  my $sitename = $self->get_site_name;
  my $article = 'a';
  if ($sitename =~ /^(a|e|i|o|u)/i) {
    $article = 'an';
  }

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $message = sprintf(qq(Hello,

 You have been invited by %s to join the %s group
 on the %s Genome Browser.

 To accept this invitation, click on the following link:

 %s/Account/Accept?id=%s;code=%s;email=%s

 If you do not wish to accept, please just disregard this email.

 If you have any problems please don't hesitate to contact %s (%s) or the %s HelpDesk (%s)
), 
  $user->name, $group->name, $sitename,
  $self->get_baseurl, $invite->id, $invite->code, $invite->email,
  $user->name, $user->email, $sitename, $self->get_from);

  $message .= $self->email_footer;
  $self->set_to($invite->email);
  $self->set_subject("Invitation to join $article $sitename group");
  $self->set_message($message);
  $self->send();
}

sub email_footer {
  my $self = shift;
  my $sitename = $self->get_site_name;
  my $footer = qq(

Many thanks,

The $sitename web team

$sitename Privacy Statement: ) . $self->get_baseurl . qq(/info/about/legal/privacy.html


);
  return $footer;
}

}

1;
