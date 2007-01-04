package EnsEMBL::Web::Commander::Connection;

use strict;
use warnings;

{

my %From_of;
my %To_of;
my %Type_of;

sub new {
  ### c
  ### Maps a connection between two nodes. This class is used to
  ### represent the links between nodes in a wizard.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $From_of{$self} = defined $params{from} ? $params{from} : undef;
  $To_of{$self} = defined $params{to} ? $params{to} : undef;
  $Type_of{$self} = defined $params{type} ? $params{type} : undef;
  return $self;
}

## accessors

sub from {
  ### a
  my $self = shift;
  $From_of{$self} = shift if @_;
  return $From_of{$self};
}

sub to {
  ### a
  my $self = shift;
  $To_of{$self} = shift if @_;
  return $To_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $From_of{$self};
  delete $To_of{$self};
}

}

1;
