package EnsEMBL::Web::Form::Field;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Div);

################## STRUCTURE OF FIELD ##################
##  <div>                                             ##
##  <label>label</label><!--left column -->           ##
##  <div>Head notes</div><!-- right col (optional)--> ##
##  <div>Elements</div><!-- right col (multiple)-->   ##
##  <div>Foot notes</div><!-- right col (optional)--> ##
##  </div>                                            ##
########################################################

use constant {
  CSS_CLASS                 => 'form-field',
  CSS_CLASS_NOTES           => 'ff-notes',
  CSS_CLASS_LABEL           => 'ff-label',
  CSS_CLASS_ELEMENT_DIV     => 'ff-right',
  CSS_CLASS_INLINE_WRAPPER  => 'inline',
  
  _IS_FOOT_NOTE             => '__is_foot_note',
  _IS_HEAD_NOTE             => '__is_head_note',
  _CAN_BE_INLINE            => '__can_be_inline',
};

sub render {
  ## @overrides
  ## Sets the "for" attribute of <label> to the first element in the field before returning html
  my $self = shift;
  
  $self->set_attribute('class', $self->CSS_CLASS);

  my $label = $self->first_child && $self->first_child->node_name eq 'label' ? $self->first_child : undef;
  if ($label) {
    my $inputs = $self->get_elements_by_tag_name(['input', 'select', 'textarea']);
    if (scalar @$inputs && $inputs->[0]->id 
      && ($inputs->[0]->node_name =~ /^(select|textarea)$/
        || $inputs->[0]->node_name eq 'input' && $inputs->[0]->get_attribute('type') =~ /^(text|password|file)$/
        || $inputs->[0]->node_name eq 'input' && $inputs->[0]->get_attribute('type') =~ /^(checkbox|radio)$/ && scalar @$inputs == 1
      )
    ) {
      $label->set_attribute('for', $inputs->[0]->id);
    }
  }
  return $self->SUPER::render;
}

sub label {
  ## Gets, modifies or adds new label to field
  ## @params String innerHTML for label
  ## @return DOM::Node::Element::Label object
  my $self = shift;
  my $label = $self->first_child && $self->first_child->node_name eq 'label'
    ? $self->first_child
    : $self->prepend_child($self->dom->create_element('label'));
  $label->set_attribute('class', $self->CSS_CLASS_LABEL);
  if (@_) {
    my $inner_HTML = shift;
    $inner_HTML .= ':' if $inner_HTML !~ /:$/;
    $label->inner_HTML($inner_HTML);
  }
  return $label;
}

sub head_notes {
  ## Gets, modifies or adds head notes to the field
  return shift->_notes('head', @_);
}

sub foot_notes {
  ## Gets, modifies or adds foot notes to the field
  return shift->_notes('foot', @_);
}

sub elements {
  ## Returns all the elements added in this field
  ## @return ArrayRef of Form::Element::* objects or Element object inside a DOM::Node::Element::Div
  my $self = shift;
  my $elements = [];
  for (@{$self->child_nodes}) {
    push @$elements, $_ unless exists $_->{$self->_IS_FOOT_NOTE}
  }
}

sub add_element {
  ## Adds a new element under existing label
  ## @params HashRef of standard parameters required for Form::Element->configure
  ## @params Inline flag - if on, tries to add the element inline with the previous element if possible

  my ($self, $params, $inline) = @_;
  
  my $children = $self->child_nodes;
  my $div = undef;

  my $element = $self->dom->create_element('form-element-'.$params->{'type'});
  $element->configure($params);
  
  if ($inline && $element->node_name =~ /^(input|textarea|select)$/) { #if possible to fulfil the request for inline
    for (reverse @{$children}) {
      next if exists $_->{$self->_IS_FOOT_NOTE};
      last unless exists $_->{$self->_CAN_BE_INLINE};
      $div = $_;
      $div->set_attribute('class', $self->CSS_CLASS_INLINE_WRAPPER);
      last;
    }
  }
  unless ($div) {
    $div = $self->dom->create_element('div');
    $div->{$self->_CAN_BE_INLINE} = 1;
    scalar @$children && exists $children->[-1]->{$self->_IS_FOOT_NOTE} ? $self->insert_before($div, $children->[-1]) : $self->append_child($div);
  }

  if ($div->is_empty && $element->node_name eq 'div') { #to avoid nesting of divs
    $self->replace_child($element, $div);
    $div = $element;
  }
  else {
    $div->append_child($element);
  }
  $div->set_attribute('class', $self->CSS_CLASS_ELEMENT_DIV);
  return $div;
}

sub is_honeypot {
  ## Sets/Gets the flag
  my $self = shift;
  $self->{'__is_honeypot'} = shift  if @_;
  return $self->{'__is_honeypot'};
}

sub _notes {
  my $self = shift;
  my $location = shift eq 'head' ? 'head' : 'foot';
  my $children = $self->child_nodes || [];
  my $notes = undef;
  my $identity_key = $location eq 'head' ? $self->_IS_HEAD_NOTE : $self->_IS_FOOT_NOTE;
  exists $_->{$identity_key} and $notes = $_ and last for (@$children);

  unless ($notes) {
    $notes = $self->dom->create_element('div');
    $notes->{$identity_key} = 1;
    $notes->set_attribute('class', $self->CSS_CLASS_NOTES);
    if ($location eq 'head') {
      scalar @$children && $children->[0]->node_name eq 'label' ? $self->insert_after($notes, $children->[0]) : $self->prepend_child($notes);
    }
    else {
      $self->append_child($notes);
    }
  }
  
  $notes->inner_HTML(shift) if @_;
  return $notes;
}

1;