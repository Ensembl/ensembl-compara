package EnsEMBL::Web::Interface::PageDefinition;

use strict;
use warnings;

{

my %Title_of;
my %Footer_of;
my %PageElements_of;
my %FormElements_of;
my %DisplayElements_of;
my %ConfigurationElements_of;
my %Action_of;
my %Send_of;
my %Cancel_of;
my %OnComplete_of;
my %OnError_of;
my %DataDefinition_of;


sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Title_of{$self}          = defined $params{title} ? $params{title} : "";
  $Footer_of{$self}          = defined $params{footer} ? $params{footer} : "";
  $OnComplete_of{$self}     = defined $params{on_complete} ? $params{on_complete} : "";
  $Send_of{$self}     = defined $params{send} ? $params{send} : {};
  $PageElements_of{$self}   = defined $params{page_elements} ? $params{page_elements} : [];
  $FormElements_of{$self}   = defined $params{form_elements} ? $params{form_elements} : [];
  $DisplayElements_of{$self}   = defined $params{display_elements} ? $params{display_elements} : [];
  $DataDefinition_of{$self} = defined $params{data_definition} ? $params{data_definition} : undef;
  $ConfigurationElements_of{$self} = defined $params{configuration_elements} ? $params{configuration_elements} : undef;
  $Action_of{$self}         = defined $params{action} ? $params{action} : undef;
  $OnError_of{$self}         = defined $params{error} ? $params{error} : undef;
  $Cancel_of{$self}         = defined $params{cancel} ? $params{cancel} : undef;
  return $self;
}

sub send_params {
  ### a
  my $self = shift;
  $Send_of{$self} = shift if @_;
  return $Send_of{$self};
}

sub send_id {
  my $self = shift;
  return $self->send_params->{id};
}

sub title {
  ### a
  my $self = shift;
  $Title_of{$self} = shift if @_;
  return $Title_of{$self};
}

sub footer {
  ### a
  my $self = shift;
  $Footer_of{$self} = shift if @_;
  return $Footer_of{$self};
}

sub configuration_elements {
  ### a
  my $self = shift;
  $ConfigurationElements_of{$self} = shift if @_;
  return $ConfigurationElements_of{$self};
}

sub add_configuration_element {
  ### Adds a configuration element to the dataview.
  my ($self, $key, $value, $options) = @_;
  if (!$self->configuration_elements) {
    $self->configuration_elements([]);
  }
  push @{ $self->configuration_elements }, { 'key' => $key, 'value' => $value, 'options' => $options };
}

sub on_complete{
  ### a
  my $self = shift;
  $OnComplete_of{$self} = shift if @_;
  return $OnComplete_of{$self};
}

sub action {
  ### a
  my $self = shift;
  $Action_of{$self} = shift if @_;
  return $Action_of{$self};
}

sub data_definition {
  ### a
  my $self = shift;
  $DataDefinition_of{$self} = shift if @_;
  return $DataDefinition_of{$self};
}

sub display_elements {
  ### a
  my $self = shift;
  $DisplayElements_of{$self} = shift if @_;
  return $DisplayElements_of{$self};
}

sub add_display_element {
  my ($self, $element, $title, $options) = @_;
  push @{$self->display_elements}, { name => $element, label => $title, options => $options};
}

sub page_elements {
  ### a
  my $self = shift;
  $PageElements_of{$self} = shift if @_;
  return $PageElements_of{$self};
}

sub cancel {
  ### a
  my $self = shift;
  $Cancel_of{$self} = shift if @_;
  return $Cancel_of{$self};
}

sub form_elements {
  ### a
  my $self = shift;
  $FormElements_of{$self} = shift if @_;
  return $FormElements_of{$self};
}

sub on_error {
  ### a
  my $self = shift;
  $OnError_of{$self} = shift if @_;
  return $OnError_of{$self};
}

sub label_for_form_element {
  ## TODO: Unify elements and data definitions into single data structure
  my ($self, $name, $option) = @_; 
  foreach my $element (@{ $self->form_elements }) {
    if ($element->{name} eq $name) {
      if (defined $element->{options} && $element->{options}->label_for_field($option)) {
        return $element->{options}->label_for_field($option);
      }
      if ($option) {
        return ucfirst($option);
      } else {
        return $element->{label};
      }
    }  
  }
  return undef;
}

sub value_for_selection_element {
  ### Returns the value associated to an option in a selection element. By default, 
  ### these form elements (selects, radio buttons etc) return the same value as their
  ### default label.
  my ($self, $name, $option) = @_;
  foreach my $element (@{ $self->form_elements }) {
    if ($element->{name} eq $name) {
      if (defined $element->{options} && $element->{options}->value_for_field($option)) {
        return $element->{options}->value_for_field($option);
      }
    }  
  }
  return $option;
}

sub description_for_form_element {
  ### Returns a description for a form element
  my ($self, $name, $option) = @_;

  foreach my $element (@{ $self->form_elements }) {
    if ($element->{name} eq $name) {
      if (defined $element->{options} && $element->{options}->description_for_field($option)) {
        return $element->{options}->description_for_field($option);
      }
    }
  }

  return undef;
}

sub value_for_form_element {
  ### Returns the value of a form element, as determined by the data retrieved from the 
  ### database. For possible return values for enumerated types, use {{value_for_selection_element}}
  my ($self, $name, $force) = @_;
  my $return_value = undef;

  my $options = $self->options_for_element($name);

  if (!$force) {
  if ($options && $options->is_conditional) {
    return $return_value;
  }
  }

  if ($self->data_definition->data) {
    $return_value = $self->data_definition->data->{$name};
  }

  if (!$return_value && $self->data_definition->data) {
    my $eval_string = $self->data_definition->data->{data};
    my $data = eval($eval_string);
    foreach my $key (%{ $data }) {
      if (!$data->{$key}) {
        delete $data->{$key};
      }
    }
    $return_value = $data->{$name};
  }


  if (!$return_value) {  
    if (defined $options && $options->value_for_field($name)) {
          $return_value = $options->value_for_field($name);
    }
  } 

  return $return_value;
}

sub options_for_element {
  my ($self, $name) = @_;
  foreach my $element (@{ $self->form_elements }) {
    if ($element->{name} eq $name) {
      if ($element->{options}) {
        return $element->{options};
      }
    }
  }
  return undef;
}

sub add_form_element {
  my ($self, $element, $title, $options) = @_;
  push @{$self->form_elements}, { name => $element, label => $title, options => $options};
}

sub options_for_form_element {
  my ($self, $name) = @_;
  my $options = {};
  foreach my $element (@{ $self->form_elements }) {
    if ($element->{name} eq $name) {
      $options = $element->{options};
    }
  }
  return $options;
}

sub add_element {
  my ($self, %params) = @_;
  push @{ $self->page_elements }, \%params;
}

sub add_text {
  my ($self, $text) = @_;
  $self->add_element((type => 'text', label => $text, field => undef));
}

sub definition_for_data_field {
  my ($self, $name) = @_;
  foreach my $element (@{ $self->data_definition->fields }) {
    if ($element->{'Field'} eq $name) {
      return $element;
    }
  }
  return undef;
}

sub DESTROY {
  my $self = shift;
  delete $Title_of{$self};
  delete $Footer_of{$self};
  delete $PageElements_of{$self};
  delete $DataDefinition_of{$self};
  delete $DisplayElements_of{$self};
  delete $Action_of{$self};
  delete $OnComplete_of{$self};
  delete $FormElements_of{$self};
  delete $ConfigurationElements_of{$self};
  delete $OnError_of{$self};
  delete $Send_of{$self};
  delete $Cancel_of{$self};
}

}

1;
