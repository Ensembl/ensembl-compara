package EnsEMBL::Web::Command::Help::MovieEmail;

### Sends the contents of the helpdesk movie feedback form (after checking for spam posting)

use strict;
use warnings;

use EnsEMBL::Web::Mailer::Help;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self  = shift;
  my $hub   = $self->hub;
  my $url   = {qw(type Help action EmailSent result 1)};

  $url->{'result'} = EnsEMBL::Web::Mailer::Help->new($hub)->send_movie_feedback_email($self->object->movie_problems) unless $hub->param('honeypot_1') || $hub->param('honeypot_2'); # check honeypot fields before sending email

  return $self->ajax_redirect($hub->url($url));
}

1;
