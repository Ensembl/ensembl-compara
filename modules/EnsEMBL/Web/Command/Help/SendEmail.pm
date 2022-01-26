=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
      map {$_   => $hub->param($_) || ''} qw(name address subject message attachment)
    };

  } else {

    $url              = {qw(type Help action EmailSent result 1)};

    $url->{'result'}  = EnsEMBL::Web::Mailer::Help->new($hub)->send_help_contact_email;
  }

  return $self->ajax_redirect($hub->url($url));
}

1;
