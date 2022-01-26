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

package EnsEMBL::Web::Form::Element::String;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Input::Text
  EnsEMBL::Web::Form::Element
);

use constant {
  VALIDATION_CLASS =>  '_string', #override in child classes
};

sub render {
  ## @overrides
  my $self = shift;
  return $self->SUPER::render(@_).$self->shortnote->render(@_);
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'value'}  = [ $params->{'value'}, 1 ] if exists $params->{'value'} && !$params->{'is_encoded'};

  $self->set_attribute($_, $params->{$_}) for grep exists $params->{$_}, qw(id name value size class maxlength style);
  $self->set_attribute('class', [$self->VALIDATION_CLASS, $params->{'required'} ? $self->CSS_CLASS_REQUIRED : $self->CSS_CLASS_OPTIONAL]);
  $self->set_attribute('class', 'default_'.$params->{'default'}) if exists $params->{'default'};

  $self->$_(1) for grep $params->{$_}, qw(disabled readonly);

  $params->{'shortnote'} = '<strong title="Required field">*</strong> '.($params->{'shortnote'} || '') if $params->{'required'} && !$params->{'no_asterisk'};
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};
}

1;