package EnsEMBL::Web::Interface::ElementDef;

### Object to define and manipulate an individual form field 

use strict;
use warnings;

{

my %Name_of;
my %Type_of;
my %Label_of;
my %Options_of;

sub new {
  my ($class, $params) = @_;
  my $self = bless \my($scalar), $class;
  $Name_of{$self}       = defined $params->{name} ? $params->{name} : '';
  $Type_of{$self}       = defined $params->{type} ? $params->{type} : '';
  $Label_of{$self}      = defined $params->{label} ? $params->{label} : '';
  $Options_of{$self}    = defined $params->{options} ? $params->{options} : {};
  return $self;
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub label {
  ### a
  my $self = shift;
  $Label_of{$self} = shift if @_;
  return $Label_of{$self};
}

sub options {
  ### a
  my $self = shift;
  $Options_of{$self} = shift if @_;
  return $Options_of{$self};
}

##-------------------------------------------------------------------------------------

sub option {
  ### Gets or sets an individual option
  my ($self, $param, $value) = @_;
  if ($param) {
    if ($value) {
      $Options_of{$self}{$param} = $value;
    }
    return $Options_of{$self}{$param};
  }
}

sub widget {
  ### Returns a ElementDefinition object's contents as a hash of 
  ### the full parameters for a Form::Element of its specified type
  my $field = shift;
  my %element;

  $element{'type'}  = $field->type;
  $element{'name'}  = $field->name;
  $element{'label'} = $field->label;

  ## unpack options into separate values
  my $options = $field->options;
  while (my ($k, $v) = each (%$options)) {
    $element{$k} = $v;
  }
  return \%element;
}

sub preview {
  ### Returns a ElementDefinition object's contents as a hash of
  ### the parameters needed for a Form::Element::NoEdit
  my $field = shift;
  my %element;
  $element{'type'} = 'NoEdit';
  $element{'name'} = $field->name;
  $element{'label'} = $field->label;
  ## also pass back dropdown values where needed
  if ($field->type eq 'DropDown' || $field->type eq 'MultiSelect') {
    my $options = $field->options;
    $element{'values'} = $options->{'values'};
  }
  return \%element;
}

sub hide {
  ### Returns a ElementDefinition object's contents as a hash of
  ### the parameters needed for a Form::Element::Hidden
  my $field = shift;
  my %element;
  $element{'type'} = 'Hidden';
  $element{'name'} = $field->name;
  return \%element;
}

sub DESTROY {
  my $self = shift;
  delete $Type_of{$self};
  delete $Label_of{$self};
  delete $Options_of{$self};
}

}

1;
