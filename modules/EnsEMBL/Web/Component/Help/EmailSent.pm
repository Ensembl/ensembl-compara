=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Help::EmailSent;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $email = $hub->species_defs->ENSEMBL_HELPDESK_EMAIL;

  return $hub->param('result')
    ? qq(<p>Thank you. Your message has been sent to our HelpDesk. You should receive a confirmation email shortly.</p>
      <p>If you do not receive a confirmation, please email us directly at <a href="mailto:$email">$email</a>. Thank you.</p>)
    : qq(<p>There was some problem sending your message. Please try again, or email us directly at <a href="mailto:$email">$email</a>. Thank you.</p>)
  ;
}

1;
