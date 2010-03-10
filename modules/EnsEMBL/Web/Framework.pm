package EnsEMBL::Web::Framework;

## NAME: EnsEMBL::Web::Framework
### A framework for controlling automated database frontends

### STATUS: Under development

### DESCRIPTION:
### This module, and its associated modules in E::W::Command::Framework
### and E::W::Component::Framework, provide a way of automating the creation
### of database frontend whilst allowing extension of the basic functionality
### through custom forms etc.

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;

  my $self = {
    '_data'           => [],
    '_form_elements'  => {},
    '_element_order'  => [],
    '_dropdown_query' => {},
    '_option_columns' => [],
    '_show_preview'   => 1,
    '_show_history'   => 0,
    '_delete_mode'  => 0,
  };

  bless $self, $class;
  return $self;
}

##----------- ACCESSORS ----------------------------------------

sub data {
### a
### Stores the EnsEMBL::Data objects being manipulated
### Takes and returns an array of objects
  my ($self, @data_objects) = @_;
  if (@data_objects) {
    $self->{'_data'} = \@data_objects;
  }
  return @{$self->{'_data'}};
}

sub form_elements {
### a
### Defines the form widgets for a given interface
### Takes and returns a hash of name => hashref pairs, where the hashref
### contains the arguments needed to create an E::W::Form::Element
  my ($self, %elements) = @_;
  if (keys %elements) {
    $self->{'_form_elements'} = \%elements;
  }
  return %{$self->{'_form_elements'}};
}

sub element_order {
### a
### Defines the default order of form widgets
### Takes and returns an array of strings, which correspond to keys in the 
### form_elements hash
  my ($self, @element_names) = @_;
  if (@element_names) {
    $self->{'_element_order'} = \@element_names;
  }
  return @{$self->{'_element_order'}};
}

sub dropdown_query {
### a
### Defines query parameters used when selecting a list of records
### to display in a "select a record" dropdown widget
### Takes a hashref in the same format as used by Rose::DB::Object::Manager
  my ($self, $query_definition) = @_;
  if ($query_definition) {
    $self->{'_dropdown_query'} = $query_definition;
  }
  return $self->{'_dropdown_query'};
}

sub option_columns {
### a
### Defines the columns to display in the "select a record" dropdown
### Takes an array of strings which must correspond to attributes
### of the objects being fetched
  my ($self, @columns) = @_;
  if (@columns) {
    $self->{'_option_columns'} = \@columns;
  }
  return @{$self->{'_option_columns'}};
}

sub show_preview {
### a
### Boolean flag - does this interface allow the user to preview
### form input before saving?
### Default is 1
  my ($self, $boolean) = @_;
  if ($boolean && $boolean =~ /^(0|1)$/) {
    $self->{'_show_preview'} = $boolean;
  }
  return $self->{'_show_preview'};
}

sub show_history {
### a
### Boolean flag - does this interface show the creation and 
### modification dates of records (with user names, where appropriate)?
### Default is 0, for privacy
  my ($self, $boolean) = @_;
  if ($boolean && $boolean =~ /^(0|1)$/) {
    $self->{'_show_history'} = $boolean;
  }
  return $self->{'_show_history'};
}

sub delete_mode {
### a
### Flag - does this interface allow the user to delete records, "retire" 
### them or is deletion not allowed at all?
### Allowed values are:
### 0 - no deletes/retirements (default)
### 1 - full deletes allowed
### {$field => $value} - retire records by setting field $field to value $value
  my ($self, $setting) = @_;
  if ($setting && ($setting =~ /^(0|1)$/ 
      || (ref($setting) eq 'HASH' && keys %$setting === 1))) {
    $self->{'_delete_mode'} = $setting;
  }
  return $self->{'_delete_mode'};
}

##------------- MANIPULATING FORM ELEMENTS ---------------------

sub element {
### Sets/gets an individual entry to the form_elements hash
### Takes a name for the element and (optionally) a hashref of attributes
  my ($self, $name, $attributes) = @_;
  return unless $name;
  if ($attributes && ref($attributes) eq 'HASH') {
    $self->{'_form_elements'}{$name} = $attributes;
  }
  return $self->{'_form_elements'}{$name};
}

sub modify_element {
### Modifies an attribute of an individual form element
### Takes the name of the element, the name of the attribute
### and (optionally) a new value for the attribute
  my ($self, $name, $attribute, $value) = @_;
  return unless $name && $attribute;
  if ($value) {
    $self->{'_form_elements'}{$name}{$attribute} = $value;
  }
}

sub add_to_form {
### Pushes an element name onto the form_elements array
  my ($self, $name) = @_;
  return unless $name;
  push @{$self->{'_element_order'}}, $name;
}

##------------ INTERFACE AUTOMATION -------------------

sub discover {
### Examines the first data object in the array and auto-generates
### form element properties based on the column type
## TODO - add related tables
  my $self = shift;
  my $data = $self->{'_data'}[0];
  return unless $data;

  foreach my $column ($data->get_all_columns) {
    my $name = $column->name;
    my $param = {};

    ## set label
    my $label = ucfirst($column->name);
    $label =~ s/_/ /g;
    $param->{'label'} = $label;

    ## set widget type
    my $data_type = $column->type;
 
    if ($name =~ /^created_|^modified_/) {
      $param->{'type'} = 'NoEdit';
    } 
    elsif ($name =~ /password/) {
      $param->{'type'} = 'Password';
    }
    elsif ($data_type eq 'integer') {
      $param->{'type'} = 'Int';
    }
    elsif ($data_type eq 'text') {
      $param->{'type'} = 'Text';
    }
    elsif ($data_type eq 'enum') {
      $param->{'type'}    = 'DropDown';
      $param->{'select'}  = 'select';
      $param->{'values'}  = $column->values;
    }
    elsif ($data_type eq 'set') {
      $param->{'type'}    = 'MultiSelect';
      $param->{'select'}  = 'select';
      $param->{'values'}  = $column->values;
    } 
    else {
      $param->{'type'} = 'String';
      if ($data_type eq 'varchar') {
        $param->{'maxlength'} = $column->length;
      }
    }

    $self->element($name, $param);
    $self->add_to_form($name);
  }
}

1;
