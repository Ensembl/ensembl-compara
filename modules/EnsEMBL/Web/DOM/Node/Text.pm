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

package EnsEMBL::Web::DOM::Node::Text;

use strict;

use base qw(EnsEMBL::Web::DOM::Node);

sub node_type {
  ## @overrides
  return shift->TEXT_NODE;
}

sub can_have_child {
  ## @overrides
  return 0;
}

sub render {
  ## @overrides
  return shift->{'_text'}; 
}

sub render_text {
  ## @overrides
  return shift->{'_text'}; 
}

sub text {
  ## Getter/Setter of text
  ## @params Text (string, can contain HTML that will not be escaped) to be set
  ## @return Text
  my $self = shift;
  $self->{'_text'} = $self->encode_htmlentities(shift) if @_;
  return $self->{'_text'};
}

1;