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

package EnsEMBL::Web::DOM::Node::Element::Generic;

use strict;
use warnings;

use EnsEMBL::Web::Attributes;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub new {
  ## @override
  my $self = shift->SUPER::new(@_);
  $self->{'_node_name'} = 'div';#default
  return $self;
}

sub node_name :AccessorMutator('_node_name'); ## @override

sub clone_node {
  ## @override
  ## Copies node name for the new clone
  my $self  = shift;
  my $clone = $self->SUPER::clone_node(@_);
  $clone->{'_node_name'} = $self->{'_node_name'};
  return $clone;
}

1;
