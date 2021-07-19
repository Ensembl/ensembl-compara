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

package EnsEMBL::Web::Form::Element::Filterable;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

sub configure {
  ## @overrrides
  my ($self, $params) = @_;

  $params->{'wrapper_class'}  = [ ref $params->{'wrapper_class'} ? @{$params->{'wrapper_class'}} : $params->{'wrapper_class'} || (), 'filterable-dropdown', '_fd' ];
  $self->{'__multiple'}       = delete $params->{'multiple'};

  $self->SUPER::configure($params);

  $self->first_child->set_attribute('class', 'first-child');
  $self->last_child->set_attribute('class', 'last-child');

  $self->append_child('div', {'class' => 'filterable-dropdown-div', 'children' => [ @{$self->child_nodes}, {
    'node_name'   => 'p',
    'class'       => '_fd_nomatch filterable-dropdown-nomatch hidden ff-checklist',
    'inner_HTML'  => $params->{'filter_no_match'} || 'No match found'
  } ]});
  $self->prepend_child('p', {
    'class'       => 'filterable-dropdown-filter _fd_filter',
    'children'    => [{
      'node_name'   => 'input',
      'type'        => 'text',
      'value'       => $params->{'filter_text'} || 'type in to filter&#8230;'
    }, {
      'node_name'   => 'span'
    }]
  });

  # add sample tag hidden element (this will be cloned by javascript)
  my $tag_attribs = $params->{'tag_attribs'} || {};
  my $tag_class   = $tag_attribs->{'class'}  || [];
     $tag_class   = [ split ' ', $tag_class ] unless ref $tag_class;

  $self->prepend_child('div', { %$tag_attribs,
    'class'       => [ @$tag_class, qw(_fd_tag hidden filterable-dropdown-tag), $self->_is_multiple ? 'removable' : 'editable' ],
    'inner_HTML'  => '<span></span><span class="_fdt_button fdt-icon"></span>'
  });
}

sub _is_multiple {
  ## @overrides
  return shift->{'__multiple'};
}

1;