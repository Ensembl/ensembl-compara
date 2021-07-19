=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  my $subject     = ($hub->param('subject') || $sd->ENSEMBL_SITETYPE . ' Helpdesk') . ' - ' . $sd->ENSEMBL_SERVERNAME;
  $subject        .= ' (FAQ)' if $hub->param('source') eq 'Faq';
  $self->subject  = $subject;
  $self->message  = sprintf "Support question from %s\n\n%s\n\nComments:\n\n%s",
    $sd->ENSEMBL_SERVERNAME,
    $self->report_header([ 'Last Search', $hub->param('string')||'-none-' ]),
    $hub->param('message')
  ;
  $self->attachment = $hub->param('attachment');

  return $self->send;
}

1;
