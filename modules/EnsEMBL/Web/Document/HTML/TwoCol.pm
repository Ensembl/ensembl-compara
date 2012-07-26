package EnsEMBL::Web::Document::HTML::TwoCol;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Document::HTML
);

sub new {
  ## @constructor
  ## @param List of arrayref of arguments as accepted by add_row method
  my $self = shift->SUPER::new;
  $self->set_attribute('class', 'twocol');
  $self->add_row(@$_) for @_;
  return $self;
}

sub add_row {
  my ($self, $label, $value, $escape_html) = @_;
  my $dom = $self->dom;

  $value  = $dom->create_element('p', {($escape_html ? 'inner_text' : 'inner_HTML') => $value})->render if $escape_html || $value !~ /^[\s\t\n]*\<(p|div|table|form|pre|ul)(\s|\>)/;
  my $lhs = $dom->create_element('div', ref $label ? $label : {'inner_HTML' => $label});
  my $rhs = $dom->create_element('div', ref $value ? $value : {'inner_HTML' => $value});

  $lhs->set_attribute('class', 'lhs');
  $rhs->set_attribute('class', 'rhs');

  return $self->append_child('div', {'class' => 'row', 'children' => [ $lhs, $rhs ]});
}

1;
