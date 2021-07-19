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

package EnsEMBL::Web::Form::Element;

### How to add new element class?
### 1. Create the required package (class) with name Web::Form::Element::MyElement
### 2. Inherit from one of the existing Element class in Web::Form::Element::* (in this folder or any plugins)
###    (eg. as in Web::Form::Element::Radiolist)
###    OR
###    Inherit from the required element class in DOM::Node::Element::* and this class respectively (MI)
###    (eg. as in Web::Form::Element::String)
### 3. In the new class, create a subroutine configure() that accepts a set of params (check this class's configure method) and
###    configures the element accordingly
### 4. Add a key with a "form-element-my_element" with value equal to the new class's name to &map_element_class in this class
###    (eg. 'form-element-dropdown' => 'EnsEMBL::Web::Form::Element::Dropdown') "form-element-" is always the prefix
###    This short name will be used as value to the 'type' key in argument to &Fieldset::add_field or &Field::add_element
### 5. DONE - check any Form::Element::* file as example

use strict;

use constant {
  CSS_CLASS_REQUIRED  => 'required',
  CSS_CLASS_OPTIONAL  => 'optional',
  CSS_CLASS_SHORTNOTE => 'snote',
  ELEMENT_HAS_WRAPPER => 'has_div_wrapper'
};

sub configure {
  ## Configures the element according to the parameters
  ## Does all the set_attribute, append_child and other DOM manipulation (depending upon params) after the element is created 
  ## Override this in the child class
  ## @params HashRef of params required for configuring the element
  ##  - type            Type of element - should match with one of keys in &map_element_class leaving the prefix
  ##  - id              Id attribute - if not options, this also goes in 'for' attribute of label.
  ##  - wrapper_id      Id attribute for the wrapper div if present (eg. in Checklist)
  ##  - name            Name attribute
  ##  - value           Value attribute for text type field or a checkbox; selected/checked value for checklist/radiolist/dropdown -  can be an ArrayRef for multiple values
  ##  - is_encoded      Flag kept on if the value does not need htmlencoding before being set as value attribute in case of String drived element or NoEdit
  ##  - shortnote       A short text to go just right the text/password/file or select, or checkbox element.
  ##  - force_wrapper   A flag for div based elements (like checklist, noedit etc) so that their wrapping div does not replace the parent div while trying avoid nesting of divs (check E::W::Form::Field::add_element)
  ##  - inline          Flag stating whether checkbox/radio buttons are to be disaplayed in a horizontal line in case of checklist/radiolist
  ##  - size            Size attribute for text input, password input or select.
  ##  - style           Style attribute works for string based input, textarea and select dropdpwn
  ##  - selectall       Flag to tell whether or not we need a selectall checkbox in case of a checklist
  ##  - values          ArrayRef of either string values, or Hashrefs with following keys (for each option, checkbox or radio)
  ##    - id            Id attribute for the option
  ##    - value         Value of the option
  ##    - selected      Flag if on, will keep this option selected
  ##    - name          name attribute incase of checkboxes. This will override the default name attribute (the one for the whole list)
  ##    - caption       Text string (or hashref set of attributes including inner_HTML or inner_text) for <option> OR <label> for checkboxes and radio buttons
  ##    - label         Same as caption for 'checklist' (label takes precedence if both provided)
  ##    - class         Class attribute for the option/checkbox/radio button
  ##    - group         If option needs to go in any <optgroup> in case of <option> or a sub heading in case of checkbox/radio
  ##    - label_first   Flag if on, keeps the label to the left of the checkbox/radiobutton (off by default)
  ##  - no_input        Flag to prevent a hidden input automatically being added from NoEdit and EditableTag element
  ##  - children        Arrayref of child nodes, only for Div element
  ##  - is_binary       Flag kept on if values for a 'yesno' dropdown, the values to the option are 1 and 0 for Yes and No respectively instead of default 'yes' and 'no'
  ##  - is_html         Flag kept on if the value is HTML (in case of NoEdit only)
  ##  - caption         String to be displayed in NoEdit element if different from value attribute of the hidden input
  ##  - filter_text     Text to be displayed in the input used for filtering the dropdown (for Filterable element only)
  ##  - filter_no_match Text to be displayed in the Filterable element dropdown if no match is found with the value entered in the input filter box
  ##  - tag_attribs     Any attributes for the tag div of filterable element (Hashref key-value pairs as expected by DOM::Node::Element::set_attribute method)
  ##  - class           Class attribute (space seperated string or arrayref for multiple classes) - goes to all the sub elements (inputs, selects, textarea)
  ##  - element_class   Class attribute for the element div
  ##  - wrapper_class   Class attribute for the wrapper (if there's any wrapper - eg. in checklist etc)
  ##  - caption_class   Class attribute for the div/span containing caption in case of a NoEdit element
  ##  - option_class    Class attribute for all the options (in case of a dropdown)
  ##  - disabled        Flag for disabled attribute
  ##  - readonly        Flag for readonly attribute
  ##  - required        Flag to tell whether this field is required to be filled before submitting form (for JS)
  ##  - no_asterisk     Flag if on, will not display an asterisk next to the element even if it's a 'required field'
  ##  - multiple        Flag for multiple attribute in <select>
  ##  - maxlength       Maxlength attribute for <input>
  ##  - max             Allowed maximum value in case of integers
  ##  - default         Default value that gets added by JS if the user leaves this element empty (in case of String input - See String element)
  ##  - checked         Checked attribute (only for Checkbox) - (For Checklist - see 'value' key)
  warn "Web::Form::Element::configure needs to be overridden in the child class";
}

sub inputs {
  ## Getter for all the input elements added of type &__input
  ## Usefull to get the input elements straight away than getting the wrapper element like a Div in some cases
  ## @return ArrayRef of DOM::Node::Element::Input::* or Select or Textarea object
  my $self = shift;
  return $self->node_name =~ /^(input|select|textarea)$/ ? [$self] : $self->get_elements_by_tag_name([qw(input select textarea)]);
}

sub map_element_class {
  ## Maps all the elements drived from this package to the dom provided in param
  ## @params DOM object for which mapping is to be done
  my ($self, $dom) = @_;
  $dom->map_element_class({
    'form-element-age'              => 'EnsEMBL::Web::Form::Element::Age',
    'form-element-button'           => 'EnsEMBL::Web::Form::Element::Button',
    'form-element-checkbox'         => 'EnsEMBL::Web::Form::Element::Checkbox',
    'form-element-checklist'        => 'EnsEMBL::Web::Form::Element::Checklist',
    'form-element-div'              => 'EnsEMBL::Web::Form::Element::Div',
    'form-element-dropdown'         => 'EnsEMBL::Web::Form::Element::Dropdown',
    'form-element-email'            => 'EnsEMBL::Web::Form::Element::Email',
    'form-element-file'             => 'EnsEMBL::Web::Form::Element::File',
    'form-element-filterable'       => 'EnsEMBL::Web::Form::Element::Filterable',
    'form-element-float'            => 'EnsEMBL::Web::Form::Element::Float',
    'form-element-html'             => 'EnsEMBL::Web::Form::Element::Html',
    'form-element-int'              => 'EnsEMBL::Web::Form::Element::Int',
    'form-element-noedit'           => 'EnsEMBL::Web::Form::Element::NoEdit',
    'form-element-nonnegfloat'      => 'EnsEMBL::Web::Form::Element::NonNegFloat',
    'form-element-nonnegint'        => 'EnsEMBL::Web::Form::Element::NonNegInt',
    'form-element-password'         => 'EnsEMBL::Web::Form::Element::Password',
    'form-element-posfloat'         => 'EnsEMBL::Web::Form::Element::PosFloat',
    'form-element-posint'           => 'EnsEMBL::Web::Form::Element::PosInt',
    'form-element-radiolist'        => 'EnsEMBL::Web::Form::Element::Radiolist',
    'form-element-reset'            => 'EnsEMBL::Web::Form::Element::Reset',
    'form-element-speciesdropdown'  => 'EnsEMBL::Web::Form::Element::SpeciesDropdown',
    'form-element-string'           => 'EnsEMBL::Web::Form::Element::String',
    'form-element-submit'           => 'EnsEMBL::Web::Form::Element::Submit',
    'form-element-text'             => 'EnsEMBL::Web::Form::Element::Text',
    'form-element-url'              => 'EnsEMBL::Web::Form::Element::Url',
    'form-element-yesno'            => 'EnsEMBL::Web::Form::Element::YesNo',
  });
}

sub shortnote {
  ## Returns a shortnote element for a given element
  ## @return Node object (span element if shornote found, an empty text node otherwise)
  my $self = shift;
  return exists $self->{'__shortnote'} ? $self->dom->create_element('span', {'class' => $self->CSS_CLASS_SHORTNOTE, 'inner_HTML' => ' '.$self->{'__shortnote'}}) : $self->dom->create_text_node;
}

sub new {
  # This class can not be instantiated, but works only when child class has muliple inheritance. So leave a warning.
  warn "Web::Form::Element::new should never get called. Perhaps you forgot to inherit your element from one of the core Web::DOM::Node::Element::Input/Select/Textarea class before this class."
}

1;
