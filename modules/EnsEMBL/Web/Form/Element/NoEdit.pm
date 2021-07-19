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

package EnsEMBL::Web::Form::Element::NoEdit;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Div);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $params->{'caption'}  = $params->{'value'} unless exists $params->{'caption'};
  $params->{'children'} = [{
    'node_name'                                           => $params->{'is_html'} ? 'div' : 'span',
    ($params->{'is_html'} ? 'inner_HTML' : 'inner_text')  => $params->{'caption'},
    $params->{'caption_class'} ? ('class'                 => $params->{'caption_class'}) : ()
  }];

  $self->SUPER::configure($params);

  return if $params->{'no_input'};

  $params->{'value'} = [ $params->{'value'}, 1 ] unless $params->{'is_encoded'};

  my $input = $self->append_child('inputhidden');
  exists $params->{$_} and $input->set_attribute($_, $params->{$_}) for qw(id name class value);
}

sub caption {
  ## Sets/gets caption for the noedit element
  my $self = shift;

  @_ and $self->first_child->inner_HTML(@_);  
  return $self->first_child->inner_HTML;
}

1;