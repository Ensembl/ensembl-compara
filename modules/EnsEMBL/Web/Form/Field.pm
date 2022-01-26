=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
  CSS_CLASS                   => 'form-field',
  CSS_CLASS_MULTIPLE_ELEMENTS => 'ff-multi',
  CSS_CLASS_NOTES             => 'ff-notes',
  CSS_CLASS_LABEL             => 'ff-label',
  CSS_CLASS_ELEMENT_DIV       => 'ff-right',
  CSS_CLASS_INLINE_WRAPPER    => 'ff-inline',
  
  _FLAG_FOOT_NOTES            => '_is_foot_note',
  _FLAG_HEAD_NOTES            => '_is_head_note',
  _FLAG_INLINE                => '_can_be_inline',
  _FLAG_ELEMENT               => '_is_field_element',
};

sub render {
  ## @overrides
  ## Sets the "for" attribute of <label> to the first element in the field before returning html
  my $self = shift;
  
  $self->set_attribute('class', $self->CSS_CLASS);

  my $label = $self->first_child && $self->first_child->node_name eq 'label' ? $self->first_child : undef;
  if ($label) {
    my $inputs = $self->inputs;
    if (scalar @$inputs
      && ($inputs->[0]->node_name =~ /^(select|textarea)$/
        || $inputs->[0]->node_name eq 'input' && $inputs->[0]->get_attribute('type') =~ /^(text|password|file)$/
        || $inputs->[0]->node_name eq 'input' && $inputs->[0]->get_attribute('type') =~ /^(checkbox|radio)$/ && scalar @$inputs == 1
      )
    ) {
      $inputs->[0]->id($self->unique_id) unless $inputs->[0]->id;
      $label->set_attribute('for', $inputs->[0]->id);
    }
  }
  return $self->SUPER::render;
}

sub configure {
  ## Configures a field
  ## @params HashRef with following keys. (or ArrayRef of similar HashRefs in case of multiple fields)
  ##  - field_class   Extra CSS className for the field div
  ##  - label         innerHTML for <label>
  ##  - helptip       helptip for the label element
  ##  - notes         innerHTML for foot notes
  ##  - head_notes    innerHTML for head notes
  ##  - elements      ArrayRef of hashRefs with keys as accepted by Form::Element::configure()
  ##  - inline        Flag if on, tries to add the elements in horizontal fashion (if possible)
  my ($self, $params) = @_;

  $self->set_attribute('class', $params->{'field_class'}) if exists $params->{'field_class'};
  $self->label($params->{'label'}, $params->{'helptip'})  if exists $params->{'label'};
  $self->head_notes($params->{'head_notes'})              if exists $params->{'head_notes'};
  $self->foot_notes($params->{'notes'})                   if exists $params->{'notes'};
  $self->add_element($_, $params->{'inline'} || 0)        for @{$params->{'elements'} || []};
  
  return $self;
}

sub label {
  ## Gets, modifies or adds new label to field
  ## @param String innerHTML for label
  ## @param Helptip text
  ## @return DOM::Node::Element::Label object
  my $self = shift;
  my $label = $self->first_child && $self->first_child->node_name eq 'label'
    ? $self->first_child
    : $self->prepend_child('label');
  $label->set_attribute('class', $self->CSS_CLASS_LABEL);
  if (@_) {
    my $inner_HTML = shift;
    if (@_ && $_[0]) {
      $label->append_children({
        'node_name'   => 'span',
        'class'       => '_ht ht',
        'title'       => $_[0],
        'inner_HTML'  => $inner_HTML =~ s/:$//r
      }, {
        'node_name'   => 'text',
        'text'        => ':'
      });
    } else {
      $label->inner_HTML($inner_HTML =~ s/:?$/:/r);
    }
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
  ## Returns all the elements inside the field
  ## @return ArrayRef of Form::Element drived objects
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_ELEMENT);
}

sub add_element {
  ## Adds a new element under existing label
  ## @param HashRef of standard parameters required for Form::Element->configure
  ## @param Inline flag - if on, tries to add the element inline with the previous element if possible
  my ($self, $params, $inline) = @_;
  
  my $children = $self->child_nodes;
  my $div = undef;

  my $element = $self->dom->create_element('form-element-'.$params->{'type'});
  
  #error handling
  if (!$element) {
    warn qq(DOM Could not create element "$params->{'type'}". Perhaps there's no corresponding class in Form::Element, or has not been mapped in Form::Element::map_element_class);
    return undef;
  }
  $element->configure($params);

  if ($inline && $element->node_name =~ /^(input|textarea|select)$/) { #if possible to fulfil the request for inline
    for (reverse @$children) {
      next if $_->get_flag($self->_FLAG_FOOT_NOTES);
      last unless $_->get_flag($self->_FLAG_INLINE);
      $div = $_;
      $div->set_attribute('class', $self->CSS_CLASS_INLINE_WRAPPER);
      last;
    }
  }

  # add a class to the field to adjust padding among multiple elements/notes
  $self->set_attribute('class', $self->CSS_CLASS_MULTIPLE_ELEMENTS) if grep {$_->node_name eq 'div'} @$children;

  unless ($div) {
    $div = $self->dom->create_element('div');
    $div->set_flag($self->_FLAG_INLINE);
    scalar @$children && $children->[-1]->get_flag($self->_FLAG_FOOT_NOTES) ? $self->insert_before($div, $children->[-1]) : $self->append_child($div);
  }

  if ($div->is_empty && $element->node_name eq 'div' && !$element->get_flag($element->ELEMENT_HAS_WRAPPER)) { #to avoid nesting of divs
    $self->replace_child($element, $div);
    $div = $element;
  }
  else {
    $div->append_child($element);
  }
  $div->set_attribute('class', [ $self->CSS_CLASS_ELEMENT_DIV, ref $params->{'element_class'} ? @{$params->{'element_class'}} : $params->{'element_class'} || () ]);
  $div->set_flag($self->_FLAG_ELEMENT);
  return $div;
}

sub inputs {
  ## Gets all input, select or textarea nodes present in the field
  ## @return ArrayRef of DOM::Node::Element::Select|TextArea and DOM::Node::Element::Input::*
  return shift->get_elements_by_tag_name([qw(input select textarea)]);
}

sub _notes {
  my $self = shift;
  my $location = shift eq 'head' ? 'head' : 'foot';
  my $identity_flag = $location eq 'head' ? $self->_FLAG_HEAD_NOTES : $self->_FLAG_FOOT_NOTES;
  my $notes = $self->get_child_nodes_by_flag($identity_flag);
  if (scalar @$notes) {
    $notes = shift @$notes;
  }
  else {
    $notes = $self->dom->create_element('div');
    $notes->set_flag($identity_flag);
    $notes->set_attribute('class', $self->CSS_CLASS_NOTES);
    if ($location eq 'head') {
      $self->first_child && $self->first_child->node_name eq 'label' ? $self->insert_after($notes, $self->first_child) : $self->prepend_child($notes);
    }
    else {
      $self->append_child($notes);
    }
  }
  $notes->inner_HTML(shift) if @_;
  return $notes;
}

1;
