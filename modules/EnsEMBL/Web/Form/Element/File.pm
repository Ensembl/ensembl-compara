=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Form::Element::File;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::File
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name class);
  $self->set_attribute('class', $self->CSS_CLASS_REQUIRED)  if exists $params->{'required'};
  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
}

1;