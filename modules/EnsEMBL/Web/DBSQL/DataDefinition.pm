package EnsEMBL::Web::DBSQL::DataDefinition;

use strict;
use warnings;

{

my %Fields_of;
my %Relationships_of;
my %Adaptor_of;
my %Id_of;
my %Data_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Fields_of{$self}   = defined $params{fields} ? $params{fields} : [];
  $Relationships_of{$self}   = defined $params{relationships} ? $params{relationships} : [];
  $Adaptor_of{$self}   = defined $params{adaptor} ? $params{adaptor} : [];
  $Id_of{$self}   = defined $params{id} ? $params{id} : undef;
  $Data_of{$self}   = defined $params{data} ? $params{data} : undef;
  return $self;
}

sub relationships {
  ### a
  my $self = shift;
  $Relationships_of{$self} = shift if @_;
  return $Relationships_of{$self};
}

sub add_relationship {
  ### Adds a relationship to the data definition
  my ($self, $relationship) = @_;
  push @{ $self->relationships }, $relationship;
}

sub fields {
  ### a
  my $self = shift;
  $Fields_of{$self} = shift if @_;
  return $Fields_of{$self};
}

sub discover {
  my ($self, $table) = @_;
  if ($table) {
    return $self->adaptor->discover($table);
  } else {
    $self->fields($self->adaptor->discover);
  }
  return $self->fields;
}

sub populate {
  my ($self) = @_;
  $self->data($self->adaptor->fetch_id($self->id)->{$self->id});
}

sub adaptor {
  ### a
  my $self = shift;
  $Adaptor_of{$self} = shift if @_;
  return $Adaptor_of{$self};
}

sub id {
  ### a
  my $self = shift;
  $Id_of{$self} = shift if @_;
  return $Id_of{$self};
}

sub data {
  ### a
  my $self = shift;
  $Data_of{$self} = shift if @_;
  return $Data_of{$self};
}

sub add_field {
  my ($self, $field) = @_;
  push @{ $self->fields }, $field;
}

sub DESTROY {
  my $self = shift;
  delete $Fields_of{$self};
  delete $Adaptor_of{$self};
  delete $Relationships_of{$self};
  delete $Id_of{$self};
  delete $Data_of{$self};
}

}

1;
