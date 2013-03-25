package EnsEMBL::Web::Command::Help::SendEmail;

## Sends the contents of the helpdesk contact form (after checking for spam posting)

use strict;
use warnings;

use EnsEMBL::Web::Mailer::Help;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $url;

  if ($hub->param('submit') eq 'Back') {

    $url = {
      'type'    => 'Help',
      'action'  => 'Contact',
      map {$_   => $hub->param($_) || ''} qw(name address subject message)
    };

  } else {

    $url              = {qw(type Help action EmailSent result 1)};
    $url->{'result'}  = EnsEMBL::Web::Mailer::Help->new($hub)->send_help_contact_email unless $hub->param('honeypot_1') || $hub->param('honeypot_2'); # check honeypot fields before sending email
  }

  return $self->ajax_redirect($hub->url($url));
}

1;