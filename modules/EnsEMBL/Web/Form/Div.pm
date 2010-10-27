package EnsEMBL::Web::Form::Div;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node::Element::Div EnsEMBL::Web::Form::Box);

use constant {
  HEADING_TAG           => 'h3',
  CSS_CLASS             => '',
  CSS_CLASS_HEADING     => '',
  CSS_CLASS_HEAD_NOTES  => '',
  CSS_CLASS_FOOT_NOTES  => '',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('class', $self->CSS_CLASS);
  $self->{'__inner_div'} = $self->dom->create_element('div');
  $self->{'__inner_div'}->set_attribute('class', 'innerdiv'); #debug
  $self->append_child($self->{'__inner_div'});
  return $self;
}

sub render {
  ## @overrides
  ## Removes unwanted empty divs before outputting HTML
  my $self = shift;
  foreach my $child_node (@{ $self->child_nodes }) {
    for (@{ $child_node->child_nodes }) {
      $child_node->remove_child($_) if $_->can_have_child && !$_->has_child_nodes && $_->inner_HTML eq '';
    }
    $self->remove_child($child_node) if $child_node->can_have_child && !$child_node->has_child_nodes && $child_node->inner_HTML eq '';
  }
  return $self->SUPER::render;
}

sub inner_div {
  ## Gets the inner div
  ## @return Node::Element::Div object
  return shift->{'__inner_div'};
}

1;