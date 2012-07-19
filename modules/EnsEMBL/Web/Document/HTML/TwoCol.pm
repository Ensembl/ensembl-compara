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
  my ($self, $label, $value, $is_html) = @_;

  my $lhs = $self->dom->create_element('div', ref $label ? $label : {($is_html ? 'inner_HTML' : 'inner_text') => $label});
  my $rhs = $self->dom->create_element('div', !ref $value ? $is_html ? {'inner_HTML' => $value} : {'children' => [{'node_name' => 'p', 'inner_text' => $value}]} : $value);

  $lhs->set_attribute('class', 'lhs');
  $rhs->set_attribute('class', 'rhs');

  return $self->append_child('div', {'class' => 'row', 'children' => [ $lhs, $rhs ]});
}

1;
