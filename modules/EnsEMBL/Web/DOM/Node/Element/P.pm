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

package EnsEMBL::Web::DOM::Node::Element::P;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'p';
}

sub w3c_appendable {
  ## @overrides
  my ($self, $child) = @_;
  return 
       $child->node_type == $self->ELEMENT_NODE && ($child->element_type == $self->ELEMENT_TYPE_INLINE || $child->element_type == $self->ELEMENT_TYPE_SCRIPT)
    || $child->node_type == $self->TEXT_NODE
    || $child->node_type == $self->COMMENT_NODE
    ? 1 : 0
  ;
}

1;