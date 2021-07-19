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

package EnsEMBL::Web::Document::TwoCol;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Div);

sub new {
  ## @constructor
  ## @param Hashref with keys:
  ##  - striped: flag if kept on, will display rows in alternative bg colours
  ## @param List of arrayref of arguments as accepted by add_row method
  my $self = shift->SUPER::new;
  $self->set_attribute('class', 'twocol');

  my $options = @_ && ref $_[0] eq 'HASH' ? shift : {};
  $self->set_flag('striped', 1) if $options->{'striped'};

  $self->add_row(@$_) for @_;

  return $self;
}

sub add_row {
  ## @param Label string, or hashref as accepted by dom->create_element
  ## @param Value string, or hashref as accepted by dom->create_element
  ## @param Flag if on, will escape HTML for the value (rhs) column
  my ($self, $label, $value, $escape_html) = @_;
  my $dom = $self->dom;

  $value  = $dom->create_element('p', {($escape_html ? 'inner_text' : 'inner_HTML') => $value})->render if $escape_html || $value !~ /^[\s\t\n]*\<(p|div|table|form|pre|ul)(\s|\>)/;
  my $lhs = $dom->create_element('div', ref $label ? $label : {'inner_HTML' => $label});
  my $rhs = $dom->create_element('div', ref $value ? $value : {'inner_HTML' => $value});

  $lhs->set_attribute('class', 'lhs');
  $rhs->set_attribute('class', 'rhs');

  my $row = $self->append_child('div', {'class' => 'row', 'children' => [ $lhs, $rhs ]});

  if (my $bg_color = $self->get_flag('striped')) {
    $row->set_attribute('class', "bg$bg_color");
    $self->set_flag('striped', 3 - $bg_color);
  }

  return $row;
}

sub add_rows {
  ## Wrapper around add_row to add multiple rows
  ## @params List of ArrayRefs of arguments as accepted by add_row
  my $self = shift;
  return map $self->add_row(@$_), @_;
}

1;
