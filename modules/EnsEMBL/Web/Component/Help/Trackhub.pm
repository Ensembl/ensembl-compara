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

package EnsEMBL::Web::Component::Help::Trackhub;

### Popup panel for situations where we don't support any of the assemblies in a hub

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);

no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $html;

  my $message = $self->get_message($hub->param('error'));  

  $html .= $message;

  return $html;
}

sub get_message {
  my ($self, $error_code) = @_;

  my %messages = (
    'not_valid_species' => '<p>The species linked to could not be found on this site. Please check the spelling in your URL, or try one of our sister sites.</p>',
  );

  return $messages{$error_code};
}


1;
