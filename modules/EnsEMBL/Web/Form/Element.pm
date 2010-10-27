package EnsEMBL::Web::Form::Element;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Tools::RandomString;

use constant {
  PREFIX_CLASS_MAP                => 'formelement-',
  CSS_CLASS_PREFIX_MAX_VALIDATION => 'max_',
  CSS_CLASS_REQUIRED              => 'required',
};

### How to add new element class?
### 1. Create the required package (class) with name Web::Form::Element::$new_element
### 2. Inherit from one of the existing Element class in Web::Form::Element::* (in this folder or any plugins)
###    (eg. as in Web::Form::Element::Honeypot)
###    OR
###    Inherit from the required element class in DOM::Node::Element::* and this class respectively (MI)
###    (eg. as in Web::Form::Element::Text)
### 3. Create a subroutine configure() in the new class which reads the params (check this class's configure method) and
###    configures the element accordingly
### 4. Add a key with a "PREFIX . $short_name" with value equal to the new class's name to $ELEMENT_CLASS_MAP in this class
###    (eg. 'formelement-dropdown' => 'EnsEMBL::Web::Form::Element::Dropdown') "formelement-" is always the prefix
###    This short name will be used as argument in ->dom::create_element().
### 5. DONE - call dom::create_element method to create this element instead using the constructor straight away.
###           call $new_element->configure() immidiately after to configure the element

my $VALIDATION_TYPES = {        #for client side validation in JavaScript
  'age'         =>  '_age',
  'email'       =>  '_email',
  'float'       =>  '_float',
  'html'        =>  '_html',
  'int'         =>  '_int',
  'nonnegfloat' =>  '_nonnegfloat',
  'nonnegint'   =>  '_nonnegint',
  'password'    =>  '_password',
  'posfloat'    =>  '_posfloat',
  'posint'      =>  '_posint',
  'string'      =>  '_string',
  'url'         =>  '_url'
};

my $ELEMENT_CLASS_MAP = {
  PREFIX_CLASS_MAP.'checklist'    => 'EnsEMBL::Web::Form::Element::Checklist',
  PREFIX_CLASS_MAP.'dropdown'     => 'EnsEMBL::Web::Form::Element::Dropdown',
  PREFIX_CLASS_MAP.'file'         => 'EnsEMBL::Web::Form::Element::File',
  PREFIX_CLASS_MAP.'noedit'       => 'EnsEMBL::Web::Form::Element::NoEdit',
  PREFIX_CLASS_MAP.'password'     => 'EnsEMBL::Web::Form::Element::Password',
  PREFIX_CLASS_MAP.'radiolist'    => 'EnsEMBL::Web::Form::Element::Radiolist',
  PREFIX_CLASS_MAP.'reset'        => 'EnsEMBL::Web::Form::Element::Reset',
  PREFIX_CLASS_MAP.'submit'       => 'EnsEMBL::Web::Form::Element::Submit',
  PREFIX_CLASS_MAP.'text'         => 'EnsEMBL::Web::Form::Element::Text',
  PREFIX_CLASS_MAP.'textarea'     => 'EnsEMBL::Web::Form::Element::Textarea',
  PREFIX_CLASS_MAP.'yesno'        => 'EnsEMBL::Web::Form::Element::YesNo',
  PREFIX_CLASS_MAP.'dascheckbox'  => 'EnsEMBL::Web::Form::Element::DASCheckBox',
};

sub configure {
  ## Configures the element according to the parameters
  ## Does all the set_attribute, append_child and other DOM manipulation (depending upon params) after the element is created 
  ## Override this in the child class
  ## @params HashRef of params required for configuring the element
  ##  - type            Type of element - should match with one of keys in $DOM_ELEMENT_CLASS_MAPPER leaving the prefix
  ##  - id              Id attribute - if not options, this also goes in 'for' attribute of label.
  ##  - name            Name attribute
  ##  - value           Value attribute for text type field, selected/checked value for checkbox/radio/select -  can be an ArrayRef for multiple values
  ##  - shortnote       A short text to go just right the text/password/file or select.
  ##  - inline          Flag stating whether checkbox/radio buttons are to be disaplayed in a horizontal line.
  ##  - size            Size attribute for text input, password input or select.
  ##  - selectall       Flag to tell whether or not we need a selectall checkbox in case of a checklist
  ##  - options         ArrayRef of Hashref for all options checkbox, radio or select with following keys each
  ##    - id            Id attribute for the option
  ##    - value         Value of the option
  ##    - caption       Caption of the option
  ##    - optgroup      If option needs to go in any <optgroup> in case of <option> or a sub heading in case of checkbox/radio
  ##  - class           CSS class
  ##  - validate_as     What should this element be validated as in JavaScript? eg. 'email', 'password', 'posint' etc
  ##  - disabled        Disabled attribute
  ##  - readonly        Readonly attribute
  ##  - required        Flag to tell whether this field is required to be filled before submitting form (basically for JS)
  ##  - multiple        Flag to tell if multiple selection of option is allowed (multiple attribute for <select> and type="checkbox" for <input>)
  ##  - maxlength       Maxlength attribute for <input>
  ##  - das             DAS object (only for DASCheckBox)
  ##  - checked         checked attribute (only for DASCheckBox)
}

sub validation_types {
  return $VALIDATION_TYPES;
}

sub map_element_class {
  ## Maps all the elements drived from this package to the dom provided in param
  ## @params DOM object for which mapping is to be done
  my ($self, $dom) = @_;
  $dom->map_element_class($ELEMENT_CLASS_MAP);
}

sub unique_id {
  ## Gives a unique string
  ## @return Unique string
  return EnsEMBL::Web::Tools::RandomString::random_string;
}