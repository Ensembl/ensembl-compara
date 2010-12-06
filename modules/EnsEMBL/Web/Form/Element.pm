package EnsEMBL::Web::Form::Element;

### How to add new element class?
### 1. Create the required package (class) with name Web::Form::Element::$new_element
### 2. Inherit from one of the existing Element class in Web::Form::Element::* (in this folder or any plugins)
###    (eg. as in Web::Form::Element::String)
###    OR
###    Inherit from the required element class in DOM::Node::Element::* and this class respectively (MI)
###    (eg. as in Web::Form::Element::String)
### 3. Create a subroutine configure() in the new class which reads the params (check this class's configure method) and
###    configures the element accordingly
### 4. Add a key with a "form-element-$short_name" with value equal to the new class's name to &map_element_class in this class
###    (eg. 'form-element-dropdown' => 'EnsEMBL::Web::Form::Element::Dropdown') "form-element-" is always the prefix
###    This short name will be used as argument in ->dom::create_element().
### 5. DONE - call dom::create_element method to create this element instead using the constructor straight away.
###           call $new_element->configure() immidiately after to configure the element

use strict;

use constant {
  CSS_CLASS_REQUIRED  => 'required',
  CSS_CLASS_OPTIONAL  => 'optional',
};

sub configure {
  ## Configures the element according to the parameters
  ## Does all the set_attribute, append_child and other DOM manipulation (depending upon params) after the element is created 
  ## Override this in the child class
  ## @params HashRef of params required for configuring the element
  ##  - type            Type of element - should match with one of keys in &map_element_class leaving the prefix
  ##  - id              Id attribute - if not options, this also goes in 'for' attribute of label.
  ##  - name            Name attribute
  ##  - value           Value attribute for text type field, selected/checked value for checkbox/radio/select -  can be an ArrayRef for multiple values
  ##  - shortnote       A short text to go just right the text/password/file or select.
  ##  - inline          Flag stating whether checkbox/radio buttons are to be disaplayed in a horizontal line in case of checklist/radiolist
  ##  - size            Size attribute for text input, password input or select.
  ##  - selectall       Flag to tell whether or not we need a selectall checkbox in case of a checklist
  ##  - values          ArrayRef of Hashref for all options checkbox, radio or select with following keys each
  ##    - id            Id attribute for the option
  ##    - value         Value of the option
  ##    - name          name attribute incase of checkboxes. This will override the default name attribute (the one for the whole list)
  ##    - caption       InnerHTML of the option OR label for checkboxes and radio buttons
  ##    - group         If option needs to go in any <optgroup> in case of <option> or a sub heading in case of checkbox/radio
  ##    - is_plain_text Flag kept on if html encoding needs to be done to the caption
  ##  - class           Class attribute
  ##  - disabled        Flag for disabled attribute
  ##  - readonly        Flag for readonly attribute
  ##  - required        Flag to tell whether this field is required to be filled before submitting form (for JS)
  ##  - multiple        Flag for multiple attribute in <select>, and for checklist, if on, makes type="checkbox" for <input> otherwise "radio"
  ##  - maxlength       Maxlength attribute for <input>
  ##  - max             Allowed maximum value in case of integers
  ##  - checked         Checked attribute (only for Checkbox or DASCheckBox) - (FOR CHECKLIST - see value key)
  ##  - das             DAS object (only for DASCheckBox)
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
    'form-element-age'          => 'EnsEMBL::Web::Form::Element::Age',
    'form-element-checkbox'     => 'EnsEMBL::Web::Form::Element::Checkbox',
    'form-element-checklist'    => 'EnsEMBL::Web::Form::Element::Checklist',
    'form-element-dascheckbox'  => 'EnsEMBL::Web::Form::Element::DASCheckBox',
    'form-element-dropdown'     => 'EnsEMBL::Web::Form::Element::Dropdown',
    'form-element-email'        => 'EnsEMBL::Web::Form::Element::Email',
    'form-element-file'         => 'EnsEMBL::Web::Form::Element::File',
    'form-element-float'        => 'EnsEMBL::Web::Form::Element::Float',
    'form-element-html'         => 'EnsEMBL::Web::Form::Element::Html',
    'form-element-int'          => 'EnsEMBL::Web::Form::Element::Int',
    'form-element-noedit'       => 'EnsEMBL::Web::Form::Element::NoEdit',
    'form-element-nonnegfloat'  => 'EnsEMBL::Web::Form::Element::NonNegFloat',
    'form-element-nonnegint'    => 'EnsEMBL::Web::Form::Element::NonNegInt',
    'form-element-password'     => 'EnsEMBL::Web::Form::Element::Password',
    'form-element-posfloat'     => 'EnsEMBL::Web::Form::Element::PosFloat',
    'form-element-posint'       => 'EnsEMBL::Web::Form::Element::PosInt',
    'form-element-radiolist'    => 'EnsEMBL::Web::Form::Element::Radiolist',
    'form-element-reset'        => 'EnsEMBL::Web::Form::Element::Reset',
    'form-element-string'       => 'EnsEMBL::Web::Form::Element::String',
    'form-element-submit'       => 'EnsEMBL::Web::Form::Element::Submit',
    'form-element-text'         => 'EnsEMBL::Web::Form::Element::Text',
    'form-element-url'          => 'EnsEMBL::Web::Form::Element::Url',
    'form-element-yesno'        => 'EnsEMBL::Web::Form::Element::YesNo',
  });
}

sub new {
  # This class can not be instantiated, but works only when child class has muliple inheritance. So leave a warning.
  warn "Web::Form::Element::new should never get called. Perhaps you forgot to inherit your element from one of the core Web::DOM::Node::Element::Input/Select/Textarea class before this class."
}

1;