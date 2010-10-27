package EnsEMBL::Web::Form;

use strict;
use warnings;
use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::DOM::Node::Element::Form EnsEMBL::Web::Form::Box);

use constant {

  ONE_COLUMN              => 'onecolunmlayout',
  TWO_COLUMN              => 'twocolunmlayout',
  MATRIX                  => 'matrixlayout',
  FLOW                    => 'flowlayout',

  CSS_CLASS_DEFAULT       => 'std',
  CSS_CLASS_HIDDEN        => 'hidden',
  CSS_CLASS_VALIDATION    => 'check',
  CSS_CLASS_FILE_UPLOAD   => 'upload',
  TARGET_FILE_UPLOAD      => 'uploadframe',

  HEADING_TAG             => 'h2',
  CSS_CLASS_HEADING       => '',
  CSS_CLASS_HEAD_NOTES    => 'form-hnotes',
  CSS_CLASS_FOOT_NOTES    => 'form-fnotes',
  
  FOOT_NOTE_REQUIRED      => 'Fields marked with * are required',

};

sub new {
  ## @overrides
  ## Creates a new DOM::Node::Element::Form and adds the required attributes before returning it
  my ($class, $name, $action, $method, $style, $needs_js_validation) = @_;

  my $self = $class->SUPER::new();
  
  $style = defined $style && $style ne '' ? [ split /\s+/, $style ] : [];

  $self->set_attribute('id',      $name);
  $self->set_attribute('action',  $action);
  $self->set_attribute('method',  $method);
  $self->set_attribute('class',   $self->CSS_CLASS_DEFAULT);
  $self->set_attribute('class',   $_) for @$style;                       
  $self->set_attribute('class',   $self->CSS_CLASS_VALIDATION)  unless defined $needs_js_validation && $needs_js_validation eq '0'; #on by default
  
  $self->dom->map_element_class ({
    $self->ONE_COLUMN => 'EnsEMBL::Web::Form::Layout::OneColumn',
    $self->TWO_COLUMN => 'EnsEMBL::Web::Form::Layout::TwoColumn',
    $self->MATRIX     => 'EnsEMBL::Web::Form::Layout::Matrix',
    $self->FLOW       => 'EnsEMBL::Web::Form::Layout::Flow',
  });

  $self->{'__layouts'}  = [];
  $self->{'__fieldset'} = $self->dom->create_element('fieldset');
  $self->append_child($self->{'__fieldset'});
  $self->set_layout($self->TWO_COLUMN); #default layout
  return $self;
}

sub render {
  ## @overrides
  ## Modifies the form before calling the inherited render method
  my $self = shift;
  
  ## Temporary - to add/remove some elements for backward compatiability
  $self->compatibility_check;
  
  ## change form attributes for uploading a file
  for (@{ $self->get_elements_by_tag_name('input') }) {
    if ($_->get_attribute('type') eq 'file') {
      $self->set_attribute('target', $self->TARGET_FILE_UPLOAD);
      $self->set_attribute('enctype', 'multipart/form-data');
      last;
    }
  }
  
  ## remove empty layout divs if any
  for (@{ $self->{'__layouts'} }) {
    $_->parent_node->remove_child($_)
      unless $_->inner_div->has_child_nodes
        || defined $_->get_heading
        || defined $_->get_head_notes
        || defined $_->get_foot_notes
        || $_->inner_div->inner_HTML ne '';
  }
  return $self->SUPER::render();
}

sub fieldset {
  ## Getter for form's fieldset
  ## @return DOM::Node::Element::Fieldset object
  return shift->{'__fieldset'};
}

sub layout {
  ## Getter of last layout added
  ## @return Form::Layout::* object
  return shift->{'__layouts'}->[-1];
}

sub layouts {
  ## Getter of all layouts added
  ## @return ArrayRef of Form::Layout::*
  return shift->{'__layouts'};
}

sub set_layout {
  ## Sets a layout for addition of sub-elements
  ## Setting a layout only affects elements being added afterwards (not the previously added elements)
  ## @params One of the layout ENUM specified in constants
  ## @return Layout object
  my ($self, $layout_type) = @_;
  $layout_type = $self->TWO_COLUMN unless $layout_type;
  push @{ $self->{'__layouts'} }, $self->dom->create_element($layout_type);
  $self->fieldset->append_child($self->{'__layouts'}->[-1]);
  return $self->{'__layouts'}->[-1];
}

sub add_hidden {
  ## Adds hidden input(s) inside the form
  ## @params ArrayRef of HashRef of name to value - { 'name' => 'value', 'name1' => 'value1' }
  ## @return HashRef of name to input object with same keys as argument provided
  my ($self, $name_value) = @_;
  my $all_hiddens = {};
  unless (exists $self->{'__hidden'}) {
    $self->{'__hidden'} = $self->dom->create_element('div');
    $self->{'__hidden'}->set_attribute('class', $self->CSS_CLASS_HIDDEN);
    $self->fieldset->insert_at_beginning($self->{'__hidden'});
  } 
  for (keys %{ $name_value }) {
    my $hidden = $self->dom->create_element('inputhidden');
    $hidden->set_attribute('name', $_);
    $hidden->set_attribute('value', $name_value->{ $_ });
    $self->{'__hidden'}->append_child($hidden);
    $all_hiddens->{ $_ } = $hidden;
  }
  return $all_hiddens;
}

sub add_buttons {
  ## Adds buttons in the form with default layout for buttons
  ## @params HashRef with following keys
  ##  - label             innerHTML for <label> if any needed for left column to the bottons
  ##  - head_notes        Head notes hashref with following keys
  ##    - text            String or arrayref of strings
  ##    - serialise       Flag to tell whether or not to display list with numbers
  ##    - text_is_html    Flag to tell not to escape HTML while adding notes
  ##  - foot_notes        Similar hashref as in head_notes
  ##    - text            String or arrayref of strings
  ##    - serialise       Flag to tell whether or not to display list with numbers
  ##    - text_is_html    Flag to tell not to escape HTML while adding notes
  ##  - buttons           ArrayRef of HashRefs - one HashRef for each element with keys as accepted by Form::Element::Button::configure()
  ## @return TwoColumn::Field object with embedded buttons
  my ($self, $params) = @_;
  my $layout  = $self->set_layout($self->TWO_COLUMN);
  for (@{ $params->{'buttons'} }) {
    unless (($_->{'type'}) =~ /^(reset|submit|image|button)$/) {
      warn 'Buttons can only be of type submit, reset, button or image.';
    }
  }
  $params->{'elements'} = $params->{'buttons'};
  delete $params->{'buttons'};
  $params->{'inline'} = 1;
  my $field   = $self->add_field($params);
  return $field;
}

sub set_subheading {
  ## Adds heading to the current layout
  ## @params Text string
  ## @params Flag to tell whether text is HTML or not
  ## @return DOM::Node::Element::H? object
  return shift->{'__layouts'}[-1]->set_heading(@_);
}

## Layout specific functions

sub add_field {           my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); }
#sub add_element {         my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); } # for onecolumnlayout - removed for backward compatiability
sub add_subheading_row {  my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); }
sub set_input_prefix {    my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); }
sub add_column {          my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); }
sub add_columns {         my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); }
sub add_row {             my $sub = (caller(0))[3]; $sub =~ /([^:]+)$/; return shift->layout->$1(@_); }





## BACKWARD COMPATIBILITY
sub compatibility_check {
  # do any changes if required pre to rendering
  my $self = shift;
  if (exists $self->{'__buttons'}) {
    $self->set_layout($self->TWO_COLUMN);
    $self->layout->inner_div->append_child($_) for @{ $self->{'__buttons'} };
  }
}
my $do_warn = 0;
sub add_element {
  my ($self, %params) = @_;
    
  my $validations = { map {$_ => 1} qw(age email float html int nonnegfloat nonnegint password posfloat posint string url) };
  my $old_type    = lc $params{'type'} || '';
  my $validate_as = exists $validations->{ $old_type } ? $old_type : undef;
  my $new_type    = $old_type;
  my $options     = [];
  my $footnotes   = {};
  $new_type = 'text' if defined $validate_as;
  
  if ($old_type eq 'password') {
    $new_type = 'password';
  }
  
  if ($old_type eq 'text') {
    $new_type = 'textarea';
  }
  
  if ($old_type eq 'dascheckbox') {
    warn 'Error: DASCheckBox needs to be modified.';
    return;
  }
  
  if ($old_type =~ /^subheader$/i) {
    $self->set_layout($self->TWO_COLUMN);
    $self->set_subheading($params{'value'} || '');
    warn "Method EnsEMBL::Web::Form::add_element is deprecated. Use Layout::set_heading() or Form::set_subheading() for providing headings within the form." if $do_warn;
    return;
  }
  
  if ($old_type =~ /^hidden$/i) {
    $self->add_hidden({
      $params{'name'} => $params{'value'},
    });
    warn "Method EnsEMBL::Web::Form::add_element is deprecated. Use Form::add_hidden for adding hidden elements" if $do_warn;
    return;
  }
  
  if ($old_type =~ /^information$/i) {
    $self->add_foot_notes({
      'text'          => $params{'value'} || '',
      'text_is_html'  => 1,
      'serialise'     => 0
    });
    warn "Method EnsEMBL::Web::Form::add_element is deprecated. Use Form::add_foot_notes or Form::add_head_notes instead for adding information" if $do_warn;
    return;
  }
  
  if ($old_type =~ /^checkbox$/i) {
    $new_type = 'checklist';
    push @$options, {
      'value' => $params{'value'},
    };
  }
  
  if ($old_type =~ /^dropdown$/i) {
    $new_type = exists $params{'select'} && $params{'select'} ? 'dropdown' : 'checklist';
    $new_type = 'checklist';
  }
  
  if (exists $params{'select'} && $params{'select'}) {
    $new_type = 'dropdown' unless $new_type eq 'yesno';
  }
  
  if ($old_type =~ /^honeypot$/i) {
    $params{'style'} = 'hidden';
    $new_type = 'text';
  }
  
  if ($old_type =~ /^forcereload$/) {
    $new_type = 'text';
    $params{'value'} = '';
  }
  
  if (exists $params{'values'} && ref($params{'values'}) eq 'ARRAY') {
    for (@{ $params{'values'} }) {
      push @$options, {
        'value'     => $_->{'value'},
        'caption'   => $_->{'name'},
        'optgroup'  => $_->{'group'},
      }
    }
  }
  
    
  $footnotes = {
    'text'          => $params{'notes'} || '',
    'text_is_html'  => 1,
    'serialise'     => 0,
  } if exists $params{'notes'} && $params{'notes'} ne '';  

  my $data = {
    'class'         => $params{'style'} || '',
    'label'         => $params{'label'} || '',
    'inline'        => 0,
    'foot_notes'    => $footnotes,
    'elements'      => [{
      'type'          => $new_type,
      'value'         => defined $params{'value'} ? $params{'value'} : '',
      'id'            => $params{'id'} || '',
      'name'          => $params{'name'} || '',
      'inline'        => 0,
      'options'       => $options,
      'class'         => $params{'style'} || '',
      'validate_as'   => $validate_as,
      'disabled'      => 0,
      'readonly'      => 0,
      'required'      => exists $params{'required'} && $params{'required'} ? 1 : 0,
      'multiple'      => $old_type =~ /^(multiselect|checkbox|combobox)$/i ? 1 : 0,
      'maxlength'     => 0,
      'rows'          => 10,
      'cols'          => 50,
    }],
  };
  
  $data->{'elements'}->[0]->{'size'} = $params{'size'} if exists $params{'size'};
  $data->{'elements'}->[0]->{'shortnote'} = $params{'shortnote'} if exists $params{'shortnote'} && defined $params{'shortnote'};

  
  if ($data->{'elements'}->[0]->{'required'} && not exists $self->{'__required'}) {
    $self->{'__required'} = 1;
    $self->add_foot_notes({'text' => $self->FOOT_NOTE_REQUIRED});
  }

  my $field = $self->add_field($data);
  
  if ($old_type =~ /^forcereload$/) {
    $field->set_attribute('class', 'modal_reload');
    $field->remove_child($_) for @{ $field->child_nodes };
  }
  
  if ($old_type =~ /^checkbox$/) {
    $field->get_elements_by_tag_name('input')->[0]->checked(1) if $params{'checked'} eq '1';
  }
  warn "Method EnsEMBL::Web::Form::add_element is deprecated. Use Form::add_field instead." if $do_warn;
  return $field;
}

sub add_notes {

  my $n = shift->add_head_notes ({
    'text'          => "<h4>$_[0]->{heading}</h4>$_[0]->{text}",
    'text_is_html'  => 1,
  });
}

sub add_fieldset {
  warn "Method EnsEMBL::Web::Form::add_fieldset is deprecated. Use Form::set_layout if you need to change form layout." if $do_warn;
}

sub add_button {
  my ($self, %params) = @_;
  $self->{'__buttons'} = [] unless exists $self->{'__buttons'};
  push @{ $self->{'__buttons'} }, $self->add_element(%params);
}

sub add_attribute {
  warn "Method EnsEMBL::Web::Form::add_attribute is deprecated. Use Form::set_attribute instead." if $do_warn;
  shift->set_attribute(@_);
}

1;