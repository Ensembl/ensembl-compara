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

package EnsEMBL::Web::Filter::Sanitize;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks form fields for whitespace and quotes that might break things!

sub catch {
  my $self   = shift;
  my $hub = $self->hub;
  
  foreach my $field ($hub->param) {
    my $value = $hub->param($field);
    $hub->param($field, $self->clean($value));
  }
}

sub clean {
  my ($self, $content) = @_;
  $content =~ s/[\r\n].*$//sm;
  $content =~ s/"//g;
  $content =~ s/''/'/g;
  return $content;
}

1;
