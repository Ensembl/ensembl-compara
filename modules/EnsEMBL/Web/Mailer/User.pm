package EnsEMBL::Web::Mailer::User::Retired;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Data::User;
use base qw(EnsEMBL::Web::Mailer);

sub send_activation_email {
  ### Sends an activation email to newly registered users.
  my ($self, $object) = @_;

  my $sitename = $self->site_name;
  my $user     = EnsEMBL::Web::Data::User->find(email => $self->to);
  
  return unless $user;

  my $message;
  
  if ($object->param('lost')) {
    $self->subject = "$sitename account reactivation";
    
    $message = sprintf("
Hello %s,

We have received a request to reactivate your Ensembl account. If you
submitted this request, click on the link below to update your password. If
not, please disregard this email.

",
      $user->name
    );
  } else {
    $self->subject = "Your new $sitename account";
    
    $message = "
Welcome to $sitename,

Thanks for registering with $sitename.

You just need to activate your account, using the link below:

";
  }

  $message .= $self->base_url . '/Account/Activate?email=' . $user->email . '&code=' . $user->salt;
  $message .= '&group_id='  . $object->param('group_id')  if $object->param('group_id');
  $message .= '&invite_id=' . $object->param('invite_id') if $object->param('invite_id');
  $message .= $self->email_footer;
  
  $self->message = $message;
  $self->send($object);
}

sub send_welcome_email {
  ### Sends a welcome email to newly registered users.
  my ($self, $object) = @_;
  
  my $sitename = $self->site_name;
  my $message  = sprintf('
Welcome to %s.

Your account has been activated! In future, you can log in to %s using your email address and the password you chose during registration:

Email: %s

More information on how to make the most of your account can be found here:

%s/info/about/accounts.html',
    $sitename, $sitename, $object->param('email'), $self->base_url
  );
  
  $message .= $self->email_footer;
  
  $self->subject = "Welcome to $sitename";
  $self->message = $message;
  $self->send($object);
}

sub send_invitation_email {
  my ($self, $object, $group, $invite) = @_;
  
  my $sitename = $self->site_name;
  my $user     = $object->user;
  my $article  = 'a';
  $article     = 'an' if $sitename =~ /^(a|e|i|o|u)/i;

  my $message = sprintf("
Hello,

You have been invited by %s to join the %s group
on the %s Genome Browser.

To accept this invitation, click on the following link:

%s/Account/Accept?id=%s&code=%s&email=%s

If you do not wish to accept, please just disregard this email.

If you have any problems please don't hesitate to contact %s (%s) or the %s HelpDesk (%s)", 
    $user->name, $group->name, $sitename,
    $self->base_url, $invite->id, $invite->code, $invite->email,
    $user->name, $user->email, $sitename, $self->from
  );

  $message .= $self->email_footer;
  
  $self->to      = $invite->email;
  $self->subject = "Invitation to join $article $sitename group";
  $self->message = $message;
  $self->send($object);
}

sub send_subscription_email {
  ### Sends an empty email to dev and announce from newly registered users.
  ### Argument $from Email id of the user 
  my ($self, $from, $object) = @_;

  my @to = qw(announce-join@ensembl.org dev-join@ensembl.org);
  
  $self->subject = "Subscription";    
  $self->message = "Subscription";
  $self->from = $from;

  for (@to) {
    $self->to = $_;
    $self->send($object);
  }
}


sub email_footer {
  my $self = shift;
  
  my $sitename = $self->site_name;
  my $footer = "
Many thanks,

The $sitename web team

$sitename Privacy Statement: $self->{'base_url'}/info/about/legal/privacy.html";
  
  return $footer;
}

1;
