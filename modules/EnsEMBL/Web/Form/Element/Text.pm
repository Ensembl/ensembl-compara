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

package EnsEMBL::Web::Form::Element::Text;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Textarea
  EnsEMBL::Web::Form::Element::String
);

use constant {
  VALIDATION_CLASS => '_text',

  DEFAULT_COLS     => 40,
  DEFAULT_ROWS     => 10,
};

sub render {
  ## @overrides
  my $self = shift;
  return $self->SUPER::render(@_).$self->shortnote->render(@_);
}

sub configure {
  ## @overrides the one in EnsEMBL::Web::Form::Element::String
  my ($self, $params) = @_;
  
  $self->SUPER::configure($params);
  
  $self->set_attribute('rows', $params->{'rows'} || $self->DEFAULT_ROWS);
  $self->set_attribute('cols', $params->{'cols'} || $self->DEFAULT_COLS);
  $self->remove_attribute('value');
  $self->remove_attribute('size');
  $self->remove_attribute('maxlength');
  $self->inner_HTML($params->{'value'}) if exists $params->{'value'};
}

1;