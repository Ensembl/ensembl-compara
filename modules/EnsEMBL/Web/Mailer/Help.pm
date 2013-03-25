package EnsEMBL::Web::Mailer::Help;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Mailer);

sub report_header {
  ## Returns a formated string for printed headers for the incoming email
  ## @return String
  my $self  = shift;
  my $hub   = $self->hub;
  my @T     = localtime;

  return join "\n", map { sprintf '%-16.16s: %s', $_->[0], $_->[1] } (
    ['Date'       => sprintf('%04d-%02d-%02d %02d:%02d:%02d', $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0])],
    ['Name'       => $hub->param('name')                                                                      ],
    ['Referer'    => $hub->species_defs->ENSEMBL_SERVERNAME                                                   ],
    ['User agent' => $ENV{'HTTP_USER_AGENT'}                                                                  ],
    @_
  );
}

sub send_movie_feedback_email {
  my $self        = shift;
  my $problems    = shift;
  my $hub         = $self->hub;
  my $sd          = $hub->species_defs;
  my %problems    = map { $_->{'value'} => $_->{'caption'} } @{$problems};

  $self->to       = $sd->ENSEMBL_HELPDESK_EMAIL;
  $self->from     = $hub->param('email');
  $self->subject  = ($hub->param('subject') || $sd->ENSEMBL_SITETYPE . ' Helpdesk') . ' - ' . $sd->ENSEMBL_SERVERNAME;
  $self->message  = sprintf "Feedback from %s\n\n%s\n\nProblem with video\n\n%s\n\n%s\n\nComments:\n\n%s",
    $sd->ENSEMBL_SERVERNAME,
    $self->report_header,
    join('', map { "* $problems{$_}\n" } $hub->param('problem')),
    $hub->param('title'),
    $hub->param('text')
  ;

  return $self->send;
}

sub send_help_contact_email {
  my $self        = shift;
  my $hub         = $self->hub;
  my $sd          = $hub->species_defs;

  $self->to       = $sd->ENSEMBL_HELPDESK_EMAIL;
  $self->from     = $hub->param('address');
  $self->subject  = ($hub->param('subject') || $sd->ENSEMBL_SITETYPE . ' Helpdesk') . ' - ' . $sd->ENSEMBL_SERVERNAME;
  $self->message  = sprintf "Support question from %s\n\n%s\n\nComments:\n\n%s",
    $sd->ENSEMBL_SERVERNAME,
    $self->report_header([ 'Last Search', $hub->param('string')||'-none-' ]),
    $hub->param('message')
  ;

  return $self->send;
}

1;
