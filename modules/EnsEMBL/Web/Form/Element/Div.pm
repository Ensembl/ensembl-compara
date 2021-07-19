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

package EnsEMBL::Web::Form::Element::Div;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $self->append_children(@{$params->{'children'}}) 					if $params->{'children'};
  $self->set_attribute('id',    $params->{'wrapper_id'})    if defined $params->{'wrapper_id'};
  $self->set_attribute('class', $params->{'wrapper_class'}) if exists $params->{'wrapper_class'};
	$self->set_flag($self->ELEMENT_HAS_WRAPPER) 							if $params->{'force_wrapper'};
}

1;
