package EnsEMBL::Web::Interface::FormDefinition;

use strict;
use warnings;

{

my %Values_of;
my %Labels_of;
my %Descriptions_of;
my %Options_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;

  $Values_of{$self}          = []; 
  $Labels_of{$self}          = [];
  $Descriptions_of{$self}    = [];
  $Options_of{$self}         = [];

  foreach my $label (@{ $params{'labels'} }) {
    $self->add_label($label);
  }

  foreach my $value (@{ $params{'values'} }) {
    $self->add_value($value);
  }

  foreach my $description (@{ $params{'descriptions'} }) {
    $self->add_description($description);
  }

  return $self;
}

sub values {
  ### a
  my $self = shift;
  $Values_of{$self} = shift if @_;
  return $Values_of{$self};
}

sub options {
  ### a
  my $self = shift;
  $Options_of{$self} = shift if @_;
  return $Options_of{$self};
}

sub add_option {
  my ($self, $option) = @_;
  push @{ $self->options }, $option;
}

sub add_value {
  ### Adds a new value to the form definition, for a specified form field.
  ### Values are returned to the database handler, if defined for a field.
  my ($self, $value_def) = @_;
  my ($key) = keys %{ $value_def };
  my $value = $value_def->{$key};
  push @{ $self->values }, { name => $key, value => $value };
}

sub value_for_field {
  my ($self, $name) = @_;
    warn "Field:" . $name;
  foreach my $field (@{ $self->values }) {
    if ($field->{name} eq $name) {
      return $field->{value};
    }
  }
  return undef;
}

sub is_conditional {
  my ($self) = @_;
  foreach my $option (@{ $self->options }) {
    if ($option->{'conditional'}) {
      return 1;
    }
  }
  return 0;
}

sub labels {
  ### a
  my $self = shift;
  $Labels_of{$self} = shift if @_;
  return $Labels_of{$self};
}

sub add_label {
  ### Defines a new label for a form field element.
  ### Labels are used in place of form field names, if defined.
  my ($self, $label_def)  = @_;
  my ($key) = keys %{ $label_def };
  my $value = $label_def->{$key};
  push @{ $self->labels }, { name => $key, label => $value };
}

sub label_for_field {
  ### Returns the label for a particular field.
  my ($self, $name) = @_;
  foreach my $field (@{ $self->labels }) {
    if ($field->{name} && $name && ($field->{name} eq $name)) {
      return $field->{label};
    }
  }
  return undef;
}

sub descriptions {
  ### a
  my $self = shift;
  $Descriptions_of{$self} = shift if @_;
  return $Descriptions_of{$self};
}

sub add_description {
  ### Adds a new description for a particular field.
  my ($self, $description_def)  = @_;
  my ($key) = keys %{ $description_def };
  my $value = $description_def ->{$key};
  push @{ $self->descriptions }, { name => $key, description => $value };
}

sub description_for_field {
  ### Returns the description for a particular field.
  my ($self, $name) = @_;
  foreach my $field (@{ $self->descriptions }) {
    if ($field->{name} eq $name) {
      return $field->{description};
    }
  }
  return undef;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Values_of{$self};
  delete $Labels_of{$self};
  delete $Descriptions_of{$self};
  delete $Options_of{$self};
}

}

1;
