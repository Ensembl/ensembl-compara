package EnsEMBL::Web::Form::Layout::TwoColumn::Field;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Form::Div);

use EnsEMBL::Web::Form::Element;

use constant {
  HEADING_TAG               => 'h4',
  CSS_CLASS                 => 'form-field',
  CSS_CLASS_HEADING         => '',
  CSS_CLASS_HEAD_NOTES      => 'form-field-notes',
  CSS_CLASS_FOOT_NOTES      => 'form-field-notes',
  CSS_CLASS_LABEL           => 'form-field-label',
  CSS_CLASS_ELEMENT_DIV     => 'form-field-right',
  CSS_CLASS_TEXT_INPUT      => 'form-field-text',
  CSS_CLASS_FILE_INPUT      => 'form-field-file',
  CSS_CLASS_BUTTON          => 'form-field-button',
  CSS_CLASS_SELECT          => 'form-field-select',
  CSS_CLASS_TEXTAREA        => 'form-field-ta',
  CSS_CLASS_WRAPPER_INLINE  => 'inline',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);

  #left column
  $self->{'__label'} = $self->dom->create_element('label');
  $self->{'__label'}->set_attribute('class', $self->CSS_CLASS_LABEL);
  $self->inner_div->append_child($self->{'__label'});

  #right column
  $self->{'__element_div'} = $self->dom->create_element('div');
  $self->{'__element_div'}->set_attribute('class', $self->CSS_CLASS_ELEMENT_DIV);
  $self->inner_div->append_child($self->{'__element_div'});

  #for adding elements from EnsEMBL::Form::Element
  $self->{'__inline'} = 0;
  EnsEMBL::Web::Form::Element->map_element_class($self->dom);

  return $self;
}

sub label {
  ## Returns the label element added in the left column
  ## @return DOM::Node::Element::Label object
  return shift->{'__label'};
}

sub elements {
  ## Returns all the elements added in this field
  ## @return ArrayRef of Form::Element::* objects
  return shift->{'__element_div'}->child_nodes;
}

sub set_label {
  ## Sets label for the field
  ## @params inner_text for label tag
  my ($self, $text) = @_;
  $self->label->inner_HTML($text) if defined $text;
}

sub add_element {
  ## Adds a new element under existing label
  ## @params HashRef of standard parameters required for Form::Element->configure

  my ($self, $params) = @_;
  
  my $element = $self->dom->create_element(EnsEMBL::Web::Form::Element->PREFIX_CLASS_MAP.lc $params->{'type'});
  
  my $wrapper = $self->dom->create_element($self->{'__inline'} ? 'span' : 'div');
  
  if ($wrapper->appendable($element)) {
    $wrapper->append_child($element);
  }
  else { #override if can't be inline
    $wrapper = $self->dom->create_element('div');
    $wrapper->append_child($element);
  }
  $wrapper->set_attribute('class', $self->CSS_CLASS_WRAPPER_INLINE) if $self->{'__inline'};
  $element->configure($params);
  
  #css stuff
  $element->set_attribute('class', $self->CSS_CLASS_TEXT_INPUT) if $element->node_name eq 'input' && $element->get_attribute('type') =~ /^(text|password)$/;
  $element->set_attribute('class', $self->CSS_CLASS_FILE_INPUT) if $element->node_name eq 'input' && $element->get_attribute('type') eq 'file';
  $element->set_attribute('class', $self->CSS_CLASS_BUTTON) if $element->node_name eq 'input' && $element->get_attribute('type') =~ /^(submit|reset)$/;
  $element->set_attribute('class', $self->CSS_CLASS_SELECT) if $element->node_name eq 'select';
  $element->set_attribute('class', $self->CSS_CLASS_TEXTAREA) if $element->node_name eq 'textarea';
  
  $self->{'__element_div'}->append_child($wrapper);
  return $wrapper;
}

1;