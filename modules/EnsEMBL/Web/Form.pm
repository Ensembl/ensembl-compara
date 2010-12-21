package EnsEMBL::Web::Form;

use strict;

## TODO - remove backward compatibility patches when ok to remove

################## Structure of form ###################
##  <form>                                            ##
##  <h2>HEADING</h2><!--single-->                     ##
##  <div>HEAD NOTES</div><!--multiple-->              ##
##  <fieldset>ALL ELEMENTS</fieldset><!--multiple-->  ##
##  <div>FOOT NOTES</div><!--multiple-->              ##
##  </form>                                           ##
########################################################

use base qw(EnsEMBL::Web::DOM::Node::Element::Form);

use EnsEMBL::Web::Form::Element;

use constant {

  CSS_CLASS_DEFAULT       => 'std',
  CSS_CLASS_VALIDATION    => 'check',
  CSS_CLASS_FILE_UPLOAD   => 'upload',
  TARGET_FILE_UPLOAD      => 'uploadframe',

  HEADING_TAG             => 'h2',
  CSS_CLASS_HEADING       => '',
  NOTES_HEADING_TAG       => 'h4',
  CSS_CLASS_NOTES         => 'notes',
  
  _FLAG_HEAD_NOTE         => 'is_head_note',
  _FLAG_FOOT_NOTE         => 'is_foot_note',
};

sub new {
  ## @overrides
  ## Creates a new DOM::Node::Element::Form and adds the required attributes before returning it
  ## @param HashRef with following keys
  ##  - id        id attribute of the form
  ##  - action    action attribute
  ##  - method    method attribute (post as default)
  ##  - class     Space seperatred class names for class attribute
  ##  - validate  Flag set 0 if no validation is required on JS end
  ##  - dom       DOM object (optional)
  my $class = shift;
  my $params = shift;
  
  ##compatibility patch
  if (ref($params) ne 'HASH') {
    return $class->_new($params, @_);
  }
  ##compatibility patch ends
  
  my $self = $class->SUPER::new($params->{'dom'} || undef);
  
  $self->set_attribute('id',      $params->{'id'}) if exists $params->{'id'};
  $self->set_attribute('action',  $params->{'action'}) if exists $params->{'action'};
  $self->set_attribute('method',  $params->{'method'} || 'post');
  $self->set_attribute('class',   exists $params->{'class'} ? $params->{'class'} : $self->CSS_CLASS_DEFAULT);
  $self->set_attribute('class',   $self->CSS_CLASS_VALIDATION) unless exists $params->{'validate'} && $params->{'validate'} eq '0'; #on by default

  $self->dom->map_element_class ({                            #map all form components to classes for DOM
    'form-fieldset'    => 'EnsEMBL::Web::Form::Fieldset',
    'form-field'       => 'EnsEMBL::Web::Form::Field',
    'form-matrix'      => 'EnsEMBL::Web::Form::Matrix',
  });

  EnsEMBL::Web::Form::Element->map_element_class($self->dom); #map all elements to classes for DOM

  return $self;
}

sub render {
  ## @overrides
  ## Modifies the form before calling the inherited render method
  my $self = shift;
  
  ## change form attributes for uploading a file
  for (@{$self->get_elements_by_tag_name('input')}) {
    if ($_->get_attribute('type') eq 'file') {
      $self->set_attribute('target', $self->TARGET_FILE_UPLOAD) unless $self->TARGET_FILE_UPLOAD eq '';
      $self->set_attribute('enctype', 'multipart/form-data');
      $self->add_hidden({'name' => 'uploadto', 'value' => 'iframe'});
      last;
    }
  }
  return $self->SUPER::render();
}

sub fieldsets {
  ## @return all fieldset elements added to the form
  my $self = shift;
  my $fieldsets = [];
  for (@{$self->child_nodes}) {
    push @$fieldsets, $_ if $_->node_name eq 'fieldset';
  }
  return $fieldsets;
}

sub foot_notes {
  ## @return Gets all the footnotes (Element::Div objects) added to the form
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_FOOT_NOTE);
}

sub head_notes {
  ## @return Gets all the headnotes (Element::Div objects) added to the form
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_HEAD_NOTE);
}

sub fieldset {
  ## Gets last fieldset added to the form OR if none added yet, adds a new one and returns it
  ## @return Form::Fieldset object
  my $self = shift;
  my $fieldsets = $self->fieldsets;
  return scalar @$fieldsets ? $fieldsets->[-1] : $self->add_fieldset;
}

sub add_fieldset {
  ## Adds a fieldset to the form
  ## @params String with Legend text or HashRef with following keys
  ##  - legend  Legend string
  ##  - stripes Shows the fieldset child nodes in alternative bg colour
  ##  - name    name part to go in the sub element ids
  ## @return Form::Fieldset object
  my $self = shift;
  my $fieldset = $self->dom->create_element('form-fieldset');
  if (@_) {
    my $params = ref($_[0]) eq 'HASH' ? $_[0] : {'legend' => $_[0]};
    $params->{'form_name'} = $self->id;
    $fieldset->configure($params);
  }

  my $foot_notes = $self->foot_notes;
  return scalar @$foot_notes ? $self->insert_before($fieldset, $foot_notes->[0]) : $self->append_child($fieldset);
}

sub has_fieldset {
  ## Check if the form has any fieldset added
  my $self = shift;
  return scalar @{$self->get_elements_by_tag_name('fieldset')} ? 1 : 0;
}

sub heading {
  ## Gets existing or modifies existing or adds new heading at the top of the form
  ## @params Heading text (is not escaped before adding)
  ## @return DOM::Node::Element::H? object
  my $self = shift;
  my $heading = undef;
  if ($self->first_child && $self->first_child->node_name eq $self->HEADING_TAG) {
    $heading = $self->first_child;
  }
  else {
    $heading = $self->dom->create_element($self->HEADING_TAG);
    $self->prepend_child($heading); #always in the beginning
  }
  $heading->inner_HTML(shift) if @_;
  return $heading;
}

sub add_notes {
  ## Adds notes to the form (or fieldset)
  ## If 'location' and 'heading' key is missing, appends the notes to the last fieldset - all other keys are invalid then (see fieldset->add_notes)
  ## @params HashRef with the following keys
  ##  - id        Id if any for the notes div
  ##  - location  (head|foot) or head by default
  ##  - class     css class name to override the default class
  ##  - heading   heading text, goes inside the <$self->NOTES_HEADING_TAG>
  ##  - text      Text displayed inside <div>
  ##  - list      Text to be displayed in list (<ul> or <ol>)
  ##  - serialise In case of list, <ol> is used if this flag is on, otherwise <ul>
  ## @return DOM::Node::Element::Div object
  my ($self, $params) = @_;

  ## if no location or heading, add notes to fieldset
  $params->{'location'} = 'head' if exists $params->{'heading'};
  return $self->fieldset->add_notes($params) unless exists $params->{'location'};

  my $location = $params->{'location'} eq 'foot' ? 'foot' : 'head';
  
  my $notes = $self->dom->create_element('div', {'class' => $params->{'class'} || $self->CSS_CLASS_NOTES});
  $notes->set_attribute('id', $params->{'id'}) if exists $params->{'id'};
  
  if (exists $params->{'heading'}) {
    my $heading = $self->dom->create_element($self->NOTES_HEADING_TAG);
    $heading->inner_HTML($params->{'heading'});
    $notes->append_child($heading);
  }
  
  if (exists $params->{'text'}) {
    my $text = $self->dom->create_element('div');
    $text->inner_HTML($params->{'text'});
    $notes->append_child($text);
  }
  
  if (exists $params->{'list'}) {
    my $list = $self->dom->create_element($params->{'serialise'} ? 'ol' : 'ul');
    for (@{$params->{'list'}}) {
      my $li = $self->dom->create_element('li');
      $li->inner_HTML($_);
      $list->append_child($li);
    }
    $notes->append_child($list);
  }
  
  # if foot notes
  if ($location eq 'foot') {
    $notes->set_flag($self->_FLAG_FOOT_NOTE);
    return $self->append_child($notes);
  }
  
  # else if head notes
  $notes->set_flag($self->_FLAG_HEAD_NOTE);
  
  my $fieldsets = $self->fieldsets;
  return $self->insert_before($notes, $fieldsets->[0]) if scalar @$fieldsets;   # insert head note before fieldset

  my $foot_notes = $self->foot_notes;
  return $self->insert_before($notes, $foot_notes->[0]) if scalar @$foot_notes; # insert head note before foot note if no fieldset found

  return $self->append_child($notes);                                           # just append to the form if nothing found
}

sub force_reload_on_submit {
  ## Adds an empty element in the form which directs JS to refresh the page once modal popup is closed
  ## Works only with the popup modal form
  my $self = shift;
  $self->fieldset->append_child($self->dom->create_element('div'))->set_attribute('class', 'modal_reload hidden');
  return 1;
}

## Addition of new form elements is always done to last fieldset.
sub add_field {           shift->fieldset->add_field(@_);           }
sub add_honeypot_field {  shift->fieldset->add_honeypot_field(@_);  }
sub add_hidden {          shift->fieldset->add_hidden(@_);          }
sub add_matrix {          shift->fieldset->add_matrix(@_);          }
sub add_button {          shift->fieldset->add_button(@_);          }
sub add_element {         shift->fieldset->add_element(@_);         }


##################################
##                              ##
## BACKWARD COMPATIBILITY PATCH ##
##                              ##
##################################
my $do_warn = 0;
sub _new {
  my ($class, $name, $action, $method, $style) = @_;

  warn "Constructor for form is modified. Use Component->new_form if in components or pass arguments as hash." if $do_warn;
  
  return $class->new({
    'id'        => $name,
    'action'    => $action,
    'method'    => $method,
    'class'     => $style,
    'validate'  => 1,
  });
}

1;