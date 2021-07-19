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

package EnsEMBL::Web::Form::Fieldset;

use strict;

## TODO - remove backward compatibility patches when ok to remove

## Structure of fieldset:
##  - While adding fields and elements, every child node is appended at the end of the fieldset (just before buttons), except legend & hidden inputs
##  - Legend is always added at the top
##  - Hidden inputs always come after the legend
##  - Buttons always go at the bottom

use EnsEMBL::Web::Form::Element;
use EnsEMBL::Web::Exceptions;

use base qw(EnsEMBL::Web::DOM::Node::Element::Fieldset);

use constant {
  CSS_CLASS_NOTES           => 'fnotes',
  FOOT_NOTE_REQUIRED        => 'Fields marked <b>*</b> are required',
  
  CSS_CLASS_TEXT_INPUT      => 'ftext',
  CSS_CLASS_FILE_INPUT      => 'ffile',
  CSS_CLASS_BUTTON          => 'fbutton',
  CSS_CLASS_SELECT          => 'fselect',
  CSS_CLASS_TEXTAREA        => 'ftextarea',
  
  CSS_ODD_ROW               => 'bg1',
  CSS_EVEN_ROW              => 'bg2',
  
  _FLAG_FIELD               => '_is_field',
  _FLAG_ELEMENT             => '_is_element',
  _FLAG_HONEYPOT            => '_is_honeypot',
  _FLAG_BUTTON              => '_is_button',
  _FLAG_STRIPED             => '_is_striped',
  _FLAG_LEGEND              => '_is_legend',
  _FLAG_SKIP_REQUIRED_NOTES => '_no_required_notes'
};

sub add_honeypot {
  my ($self,$value) = @_;

  push @{$self->{'_honeypots'}||=[]},$value;
}

sub get_honeypots {
  my ($self,$form) = @_;

  my @hps;
  foreach my $child (@{$self->{'_child_nodes'}||[]}) {
    my $hps = [];
    $hps = $child->get_honeypots($form) if $child->can('get_honeypots');
    push @hps,@$hps if $hps;
  }
  push @hps,@{$self->{'_honeypots'}} if $self->{'_honeypots'};
  return \@hps;
}

sub render {
  ## @overrides
  my $self = shift;

  $self->prepare_to_render;

  return $self->SUPER::render;
}

sub prepare_to_render {
  ## Does some extra modifications before returning the fieldset for rendering
  my $self = shift;

  return if $self->{'__prepared_to_render'};

  unless ($self->has_flag($self->_FLAG_SKIP_REQUIRED_NOTES)) {
    $_->has_class(EnsEMBL::Web::Form::Element::CSS_CLASS_REQUIRED) and $self->add_notes($self->FOOT_NOTE_REQUIRED) and last for @{$self->inputs};
  }

  #css stuff
  my $css_class = {
    'text'          => $self->CSS_CLASS_TEXT_INPUT,
    'password'      => $self->CSS_CLASS_TEXT_INPUT,
    'file'          => $self->CSS_CLASS_FILE_INPUT,
    'submit'        => $self->CSS_CLASS_BUTTON,
    'button'        => $self->CSS_CLASS_BUTTON,
    'reset'         => $self->CSS_CLASS_BUTTON,
    'select'        => $self->CSS_CLASS_SELECT,
    'textarea'      => $self->CSS_CLASS_TEXTAREA
  };
  for (@{$self->inputs}) {
    my $key = $_->node_name eq 'input' ? $_->get_attribute('type') : $_->node_name;
    $_->set_attribute('class', $css_class->{$key}) if exists $css_class->{$key};
  }

  my $i = 0;
  if ($self->has_flag($self->_FLAG_STRIPED)) {
    for (@{$self->child_nodes}) {
      next if $_->node_name eq 'input' || $_->has_flag($self->_FLAG_LEGEND) || $_->has_flag($self->_FLAG_HONEYPOT) || $_->has_flag($self->_FLAG_BUTTON);#ignore hidden inputs, legend, honeypot and buttons
      $_->set_attribute('class', $i % 2 == 0 ? $self->CSS_EVEN_ROW : $self->CSS_ODD_ROW);
      $i++ if $_->has_flag($self->_FLAG_FIELD) || $_->has_flag($self->_FLAG_ELEMENT);
    }
  }

  $self->{'__prepared_to_render'} = 1;
}

sub configure {
  ## Configures the fieldset with some extra flags and variables
  ## @return Configured fieldset
  my ($self, $params) = @_;
  $self->legend($params->{'legend'})                if $params->{'legend'};
  $self->set_flag($self->_FLAG_STRIPED)             if $params->{'stripes'};
  $self->set_flag($self->_FLAG_SKIP_REQUIRED_NOTES) if $params->{'no_required_notes'};
  return $self;
}

sub elements {
  ## Gets all the element child nodes (immediate only) in the fieldset (excluding the ones nested in the fields)
  ## @return ArrayRef of Form::Element drived objects
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_ELEMENT);
}

sub fields {
  ## Gets all the field child nodes (immediate only) in the fieldset
  ## @return ArrayRef of Form::Fields
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_FIELD);
}

sub inputs {
  ## Gets all input, select or textarea nodes present in the fieldset
  ## @return ArrayRef of DOM::Node::Element::Select|TextArea and DOM::Node::Element::Input::*
  return shift->get_elements_by_tag_name([qw(input select textarea)]);
}

sub legend {
  ## Modifies or adds a legend to the fieldset
  ## @params Inner html string
  ## @return DOM::Node::Element::H2 object
  my $self = shift;
  my $legend = $self->get_legend;
  unless ($legend) {
    $legend = $self->dom->create_element('h2', {'flags' => $self->_FLAG_LEGEND});
    $self->prepend_child($legend);
  }
  $legend->inner_HTML(shift) if @_;
  return $legend;
}

sub get_legend {
  ## Gets the legend of the fieldset
  ## @return DOM::Node::Element::H2 object or undef
  my $self = shift;
  return $self->first_child && $self->first_child->has_flag($self->_FLAG_LEGEND) ? $self->first_child : undef;
}

sub add_field {
  ## Adds a field to the form
  ## Each field is a combination of one label on the left column of the layout and one (or more) elements (input, select, textarea) on the right column. 
  ## @params HashRef with following keys. (or ArrayRef of similar HashRefs in case of multiple fields)
  ##  - field_class       Extra CSS className for the field div
  ##  - label             innerHTML for <label>
  ##  - helptip           helptip for label element
  ##  - notes             innerHTML for foot notes
  ##  - head_notes        innerHTML for head notes
  ##  - inline            Flag to tell whether all elements are to be displayed in a horizontal line
  ##  - elements          HashRef with keys as accepted by Form::Element::configure() OR ArrayRef of similar HashRefs in case of multiple elements
  ##                      In case of only one element, 'elements' key can be missed giving all child keys of 'elements' hashref to parent hashref.
  ##  - Other keys can also be considered - see elements key.
  my ($self, $params) = @_;

  if (ref($params) eq 'ARRAY') { #call recursively for multiple addition
    my $return = [];
    push @$return, $self->add_field($_) for @$params;
    return $return;
  }

  my $field_params  = { map {exists $params->{$_} ? ($_, delete $params->{$_}) : ()} qw(field_class label helptip head_notes notes inline) };
  my $elements      = exists $params->{'elements'} ? ref($params->{'elements'}) eq 'HASH' ? [ $params->{'elements'} ] : $params->{'elements'} : $params->{'type'} ? [ $params ] : [];
  my $is_honeypot   = 0;

  for (@$elements) {

    # if honeypot element
    if (lc $_->{'type'} eq 'honeypot') {
      $_->{'type'} = 'text';
      $field_params->{'field_class'} = sprintf('hidden %s', $field_params->{'field_class'} || '');
      $is_honeypot = 1;
      $self->add_honeypot($_->{'name'});
    }

    $_->{'no_asterisk'} ||= $self->has_flag($self->_FLAG_SKIP_REQUIRED_NOTES);
    $_->{'id'}          ||= $self->_next_id;
  }

  my $field = $self->dom->create_element('form-field')->configure({%$field_params, 'elements', $elements});

  $field->set_flag($self->_FLAG_HONEYPOT) if $is_honeypot;
  $field->set_flag($self->_FLAG_FIELD);
  my $last_field = $self->last_child;
  return $last_field && $last_field->has_flag($self->_FLAG_BUTTON) ? $self->insert_before($field, $last_field) : $self->append_child($field);
}

sub add_matrix {
  ## Adds a new matrix to the fieldset
  ## @return Form::Matrix object
  my $self = shift;
  return $self->append_child($self->dom->create_element('form-matrix'));
}

sub _add_element {## TODO - remove prefixed underscore once compatibile 
  ## Adds an element to the fieldset
  ## Use add_field if label is needed (Element does not contain a label itself)
  ## @params HashRef of keys as accepted by Form::Element::configure()
  ## @return Form::Element's child class object OR DOM::Node::Element::Div object if Element is not inherited from Div
  my ($self, $params) = @_;
  
  if (ref($params) eq 'ARRAY') { #call recursively for multiple addition
    my $elements = [];
    push @$elements, $self->add_element($_) for @$params;
    return $elements;
  }

  my $element = $self->dom->create_element('form-element-'.$params->{'type'});

  #error handling
  throw exception(
    'FormException::UnknownElementException',
    qq(DOM Could not create element "$params->{'type'}". Perhaps there's no corresponding class in Form::Element, or has not been mapped in Form::Element::map_element_class)
  ) unless $element;

  $params->{'id'} ||= $self->_next_id;
  $element->configure($params);
  $element = $self->dom->create_element('div', {'children' => [ $element ]}) if $element->node_name ne 'div';
  $element->set_flag($self->_FLAG_ELEMENT);

  return $self->append_child($element);
}

sub _add_button {## TODO - remove prefixed underscore once compatibile
  ## Adds buttons in the fieldset
  ## This is only an alias to add_field but 'elements' key is replaced with 'buttons' key along with addition of a new 'inline' key
  ## @params HashRef with following keys
  ##  - label             innerHTML for <label> if any needed for left column to the bottons (optional)
  ##  - align             [cetre(or center)|left|right|default]
  ##  - notes             innerHTML for foor notes
  ##  - head_notes        innerHTML for head notes
  ##  - buttons           HashRef with keys as accepted by Form::Element::Button::configure() OR ArrayRef of similar HashRefs if multiple buttons
  ##                      In case of only one button, 'buttons' key can be missed giving all child keys of 'buttons' hashref to parent hashref.
  ## @return Form::Field object with embedded buttons
  my ($self, $params) = @_;
  $params->{'elements'} = $params->{'buttons'} if $params->{'buttons'};
  $params->{'type'} = $params->{'type'} eq 'button' ? 'button' : 'submit';
  $params->{'inline'} = 1;
  $params->{'field_class'} = $self->CSS_CLASS_BUTTON.'-'.$params->{'align'} if $params->{'align'} =~ /^(centre|center|left|right)$/;
  delete $params->{'buttons'};
  my $field = $self->add_field($params);
  $field->set_flag($self->_FLAG_BUTTON);
  return $self->append_child($field); ## to make sure it's added in the end if there are multiple buttons
}

sub add_hidden {
  ## Adds hidden input(s) inside the fieldset
  ## @params HashRef with the following keys OR ArrayRef of the similar Hashes if muliple addition needed
  ##  - id            Id attribuite
  ##  - name          Name attribute
  ##  - value         Value attribute
  ##  - class         Class attribute
  ##  - is_encoded    Flag kept on, if value does not need any HTML encoding
  ## @return Input object added OR ArrayRef of all Input objects in case of multiple addition
  my ($self, $params) = @_;
  
  if (ref($params) eq 'ARRAY') { #call recursively for multiple addition
    my $return = [];
    push @$return, $self->add_hidden($_) for @$params;
    return $return;
  }

  warn 'Hidden element needs to have a name.' and return undef unless exists $params->{'name'};
  $params->{'value'} = '' unless exists $params->{'value'};
  $params->{'value'} = [ $params->{'value'}, 1 ] unless $params->{'is_encoded'};

  my $hidden = $self->dom->create_element('inputhidden', {
    'name'  => $params->{'name'},
    'value' => $params->{'value'}
  });

  $hidden->set_attribute('id',    $params->{'id'})    if $params->{'id'};
  $hidden->set_attribute('class', $params->{'class'}) if $params->{'class'};
  my $reference = $self->first_child;
  $reference = $reference->next_sibling while $reference && ($reference->node_name eq 'input' || $reference->has_flag($self->_FLAG_LEGEND));
  return $reference ? $self->insert_before($hidden, $reference) : $self->append_child($hidden);
}

sub add_notes {
  ## Appends a div to the fieldset with notes HTML inside
  ## @params String text or HashRef {'text' =>? , 'class' => ?, 'list' => ?, 'serialise' => 1/0} or ArrayRef of either of these for multiple addition
  ##  - text      Text to go inside the notes
  ##  - class     Class attribute for the wrapping <div>
  ##  - list      ArrayRef of Strings that need to go inside the notes as a list
  ##  - serialise Flag if on, uses <ol> for the list, otherwise <ul>.
  ## @return DOM::Node::Element::Div object
  my ($self, $params) = @_;
  
  if (ref $params eq 'ARRAY') { # call recursively for multiple addition
    my $return = [];
    push @$return, $self->add_notes($_) for @$params;
    return $return;
  }

  $params = { 'text' => $params } unless ref $params eq 'HASH';

  my $notes = $self->append_child('div', {'class' => $params->{'class'} || $self->CSS_CLASS_NOTES});

  $notes->inner_HTML($params->{'text'}) if exists $params->{'text'};
  $notes->append_child({
    'node_name' => $params->{'serialise'} ? 'ol' : 'ul',
    'children'  => [ map {'node_name' => 'li', 'inner_HTML' => $_}, @{$params->{'list'}} ],
  }) if exists $params->{'list'};

  return $notes;
}

## Other helper methods
sub _next_id {
  my $self = shift;
  $self->{'__next_id'}    ||= 1;
  $self->{'__unique_id'}  ||= $self->unique_id;
  return $self->{'__unique_id'}.'_'.($self->{'__next_id'}++);
}


##################################
##                              ##
## BACKWARD COMPATIBILITY PATCH ##
##                              ##
##################################

sub add_element {
  my $self    = shift;
  my @caller  = caller;
  
  ## Call new add_element method if argument is HashRef or ArrayRef
  return $self->_add_element($_[0]) if ref($_[0]) =~ /^(HASH|ARRAY)$/;
  
#  warn "Method add_element is deprecated. Please use an appropriate method at $caller[1] line $caller[2].\n";

  my %params = @_;

  $params{'class'} ||= '';
  $params{'class'} .= ref($params{'classes'}) eq 'ARRAY' ? join(' ', @{$params{'classes'}}) : $params{'classes'};

  ## Hidden
  if ($params{'type'} eq 'Hidden') {
    return $self->add_hidden({
      'name'  => $params{'name'},
      'value' => $params{'value'}, 
      'class' => $params{'class'},
      'id'    => $params{'id'},
    });
  }
  
  ## Remove extra hidden input for NoEdit fields
  $params{'no_input'} = 1;

  ## SubHeader is now new fieldset's legend
  return $self->form->add_fieldset($params{'value'}) if $params{'type'} eq 'SubHeader';

  ## Information is now fieldset's notes
  return $self->add_notes($params{'value'}) if $params{'type'} eq 'Information';
  
  ## ForceReload
  return $self->form->force_reload_on_submit($params{'url'}) if $params{'type'} eq 'ForceReload';

  ## 'name' key for options is changed to 'caption' key - name key corresponds to name attribute only
  foreach my $option (@{$params{'values'}}) { 
    $option = {'value' => $option, 'caption' => $option} if ref($option) ne 'HASH';
    if (exists $option->{'name'}) {
      $option->{'caption'} = delete $option->{'name'};
    }
  }

  # DropDown, RadioGroup, RadioButton, CheckBox, MultiSelect
  $params{'type'}     = exists $params{'select'} && $params{'select'} ? 'dropdown' : 'radiolist' if $params{'type'} eq 'DropDown';
  $params{'type'}     = 'radiolist' if $params{'type'} =~ /^(radiogroup|radiobutton)$/i;
  $params{'type'}     = 'dropdown' and $params{'multiple'} = 1 if $params{'type'} eq 'MultiSelect';
  $params{'checked'}  = $params{'selected'} if $params{'type'} =~ /checkbox/i;

  ## DropDownAndSubmit
  if ($params{'type'} eq 'DropDownAndSubmit') {
    $params{'type'} = exists $params{'select'} && $params{'select'} ? 'dropdown' : 'radiolist';
    return $self->add_field({
      'label'       => $params{'label'},
      'field_class'  => $params{'style'},
      'inline'      => 1,
      'elements'    => [\%params, {'type' => 'submit', 'value' => $params{'button_value'}}]
    });
  }
  
  ## Element is now Field.
  my $field = $self->add_field(\%params);

  return $field;
}

sub add_button {
  my $self = shift;
  return $self->_add_button($_[0]) if (ref($_[0]) =~ /^(ARRAY|HASH)$/);

  my %params = @_;
  $params{'class'} ||= '';
  $params{'class'} .= ref($params{'classes'}) eq 'ARRAY' ? join(' ', @{$params{'classes'}}) : $params{'classes'};
  return $self->_add_button(\%params);
}

1;
