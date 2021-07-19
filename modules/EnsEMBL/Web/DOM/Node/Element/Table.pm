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

package EnsEMBL::Web::DOM::Node::Element::Table;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'table';
}

sub w3c_appendable {
  ## @overrides
  my ($self, $child) = @_;
  return $child->node_type == $self->ELEMENT_NODE && $child->node_name =~ /^(caption|colgroup|col|tbody|tfoot|thead|tr)$/ ? 1 : 0;
}

sub rows {
  ## Gets an arrayref of all the rows inside the table
  return [ map { $_->node_name =~ /^t(.*)$/ ? $1 eq 'r' ? $_ : (@{$_->child_nodes}) : () } @{shift->child_nodes} ];
}

sub cells {
  ## Gets an arrayref of all the cells in the table
  return [ map {(@{$_->cells})} @{shift->rows} ];
}

1;