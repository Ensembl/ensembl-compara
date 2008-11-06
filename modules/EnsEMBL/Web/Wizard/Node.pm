package EnsEMBL::Web::Wizard::Node;

### Package to define an individual node within a wizard

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Form::FieldSet;

{

my %Type :ATTR(:set<type> :get<type> :init_arg<type>);
my %Title :ATTR(:set<title> :get<title>);
my %Name :ATTR(:set<name> :get<name> :init_arg<name>);
my %Object :ATTR(:set<object> :get<object> :init_arg<object>);
my %Elements :ATTR(:set<elements> :get<elements> :init_arg<elements>);
my %FieldSets :ATTR(:set<fieldsets> :get<fieldsets>);
my %Parameter :ATTR(:set<parameter> :get<parameter> :init_arg<parameter>);
my %Notes :ATTR(:set<notes> :get<notes>);
my %Backtrack :ATTR(:set<backtrack> :get<backtrack> :init_arg<backtrack>);

## Deprecated
my %TextAbove :ATTR(:set<textabove> :get<textabove>);
my %TextBelow :ATTR(:set<textbelow> :get<textbelow>);

sub BUILD {
  ### c
  ### Creates a new inside-out Node object. These objects are linked together
  ### to form a wizard interface controlled by the
  ### {{EnsEMBL::Web::Wizard}} class.
  my ($self, $ident, $args) = @_;
  $self->set_type($args->{type});
  $self->set_name($args->{name});
  $self->set_object($args->{object});
  $self->set_backtrack($args->{backtrack});
  $self->set_elements([]);
  $self->set_fieldsets([]);
  $self->set_parameter({});
}

sub type {
  ### a
  ### Valid values are 'page' or 'logic'
  my $self = shift;
  $self->set_type(shift) if @_;
  return $self->get_type;
}

sub title {
  ### a
  my $self = shift;
  $self->set_title(shift) if @_;
  return $self->get_title;
}

sub name {
  ### a
  my $self = shift;
  $self->set_name(shift) if @_;
  return $self->get_name;
}

sub object {
  ### a
  my $self = shift;
  $self->set_object(shift) if @_;
  return $self->get_object;
}

sub elements {
  ### a
  my $self = shift;
  $self->set_elements(shift) if @_;
  return $self->get_elements;
}

sub fieldsets {
  ### a
  my $self = shift;
  $self->set_fieldsets(shift) if @_;
  return $self->get_fieldsets;
}

sub parameter {
  ### Accessor for individual values in the 'parameter' hashref
  my ($self, $key, $value) = @_;
  my $hash = $self->get_parameter;
  $hash->{$key} = $value if $key;
  $self->set_parameter($hash);
  if (wantarray) {
    if (ref($hash->{$key}) eq 'ARRAY') {
      return @{$hash->{$key}};
    }
    else {
      return ($hash->{$key});
    }
  }
  else {
    return $hash->{$key};
  }
}

sub notes {
  ### a
  my $self = shift;
  $self->set_notes(shift) if @_;
  return $self->get_notes;
}

sub text_above {
  ### x
  my $self = shift;
  $self->set_textabove(shift) if @_;
  return $self->get_textabove;
}

sub text_below {
  ### x
  my $self = shift;
  $self->set_textbelow(shift) if @_;
  return $self->get_textbelow;
}

sub add_element {
### Adds a form element consisting of a hash of parameters
  my( $self, %options ) = @_;
  push @{ $self->elements }, \%options;
}

sub add_fieldset {
### Adds a hashref to store separate fieldsets
### Hashref should be in the format {'legend' => '', 'elements' => [], 'layout' => ''}
### (but with values included, obviously!)
  my( $self, $fieldset ) = @_;
  push @{ $self->fieldsets }, $fieldset;
}

sub add_notes {
  my ($self, %options) = @_;
  $self->notes(\%options);
}

}

1;
