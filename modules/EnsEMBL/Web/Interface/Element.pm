package EnsEMBL::Web::Interface::Element;

### Object to define and manipulate an individual form field 

use Class::Std;
use strict;
use warnings;

{

my %Name      :ATTR(:set<name> :get<name>);
my %Type      :ATTR(:set<type> :get<type>);
my %Label     :ATTR(:set<label> :get<label>);
my %Options   :ATTR(:set<options> :get<options>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_options({});
}

sub name {
  ### a
  my $self = shift;
  $self->set_name(shift) if @_;
  return $self->get_name;
}

sub type {
  ### a
  my $self = shift;
  $self->set_type(shift) if @_;
  return $self->get_type;
}

sub label {
  ### a
  my $self = shift;
  $self->set_label(shift) if @_;
  return $self->get_label;
}

sub options {
  ### a
  my $self = shift;
  $self->set_options(shift) if @_;
  return $self->get_options;
}

##-------------------------------------------------------------------------------------

sub option {
  ### Gets or sets an individual option
  my ($self, $param, $value) = @_;
  if ($param) {
    if ($value) {
      my $hashref = $self->get_options;
      $hashref->{$param} = $value;
      $self->set_options($hashref);
    }
    return $self->get_options->{$param};
  }
}

sub widget {
  ### Returns a Element object's contents as a hash of 
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
  ### Returns a Element object's contents as a hash of
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
  ### Returns a Element object's contents as a hash of
  ### the parameters needed for a Form::Element::Hidden
  my $field = shift;
  my %element;
  $element{'type'} = 'Hidden';
  $element{'name'} = $field->name;
  return \%element;
}

}

1;
