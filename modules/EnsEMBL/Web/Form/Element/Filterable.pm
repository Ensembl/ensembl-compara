=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Form::Element::Filterable;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

use constant {
  CLASSNAME_DIV       => 'filterable-dropdown _fd',
  CLASSNAME_FILTER    => 'filterable-dropdown-filter _fd_filter',
  DEFAULT_FILTER_TEXT => 'type in to filter&#8230;'
};

sub configure {
  ## @overrrides
  my ($self, $params) = @_;

  $params->{'wrapper_class'}  = [ ref $params->{'wrapper_class'} ? @{$params->{'wrapper_class'}} : $params->{'wrapper_class'} || (), $self->CLASSNAME_DIV ];
  $params->{'force_wrapper'}  = 1;

  $self->{'__multiple'} = delete $params->{'multiple'};

  $self->SUPER::configure($params);

  $self->append_child('div', {'children' => $self->child_nodes});
  $self->prepend_child('p', {
    'class'     => $self->CLASSNAME_FILTER,
    'children'  => [{'node_name' => 'input', 'class' => 'inactive', 'type' => 'text', 'value' => $params->{'filter_text'} || $self->DEFAULT_FILTER_TEXT}]
  });
}

sub _is_multiple {
  ## @overrides
  return shift->{'__multiple'};
}

1;