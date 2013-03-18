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

1;
