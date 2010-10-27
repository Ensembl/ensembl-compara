package EnsEMBL::Web::Form::Layout::OneColumn;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Form::Layout);

use constant {
  CSS_CLASS                 => 'onecolumnlayout',
  CSS_CLASS_TEXT_INPUT      => 'form-oc-text',
  CSS_CLASS_FILE_INPUT      => 'form-oc-file',
  CSS_CLASS_BUTTON          => 'form-oc-button',
  CSS_CLASS_SELECT          => 'form-oc-select',
  CSS_CLASS_TEXTAREA        => 'form-oc-ta',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('class', $self->CSS_CLASS);
  $self->{'__elements'} = [];
  EnsEMBL::Web::Form::Element->map_element_class($self->dom);
  return $self;
}

sub elements {
  ## Returns all fields added
  ## @return ArrayRef of Web::Form::Field objects
  return shift->{'__elements'};
}

sub add_element {
  ## Adds an element to the form
  ## @params HashRef with keys as accepted by Form::Element::configure()
  my ($self, $params) = @_;
  
  my $element = $self->dom->create_element(EnsEMBL::Web::Form::Element->PREFIX_CLASS_MAP.lc $params->{'type'});
  $element->configure($params);

  my $wrapper = undef;
  if ($element->node_name ne 'div') {
    $wrapper = $self->dom->create_element('div');
    $wrapper->append_child($element);
  }

  
  #css stuff
  $element->set_attribute('class', $self->CSS_CLASS_TEXT_INPUT) if $element->node_name eq 'input' && $element->get_attribute('type') =~ /^(text|password)$/;
  $element->set_attribute('class', $self->CSS_CLASS_FILE_INPUT) if $element->node_name eq 'input' && $element->get_attribute('type') eq 'file';
  $element->set_attribute('class', $self->CSS_CLASS_BUTTON) if $element->node_name eq 'input' && $element->get_attribute('type') =~ /^(submit|reset)$/;
  $element->set_attribute('class', $self->CSS_CLASS_SELECT) if $element->node_name eq 'select';
  $element->set_attribute('class', $self->CSS_CLASS_TEXTAREA) if $element->node_name eq 'textarea';

  $self->inner_div->append_child($wrapper || $element);
  push @{ $self->{'__elements'} }, $element;
  return $element;
}

1;