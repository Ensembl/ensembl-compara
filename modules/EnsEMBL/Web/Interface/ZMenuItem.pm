package EnsEMBL::Web::Interface::ZMenuItem;

use strict;
use warnings;

{

my %Type_of;
my %Text_of;
my %Name_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Type_of{$self}    = defined $params{type} ? $params{type} : "";
  $Name_of{$self}    = defined $params{name} ? $params{name} : "";
  $Text_of{$self}    = defined $params{text} ? $params{text} : "";
  return $self;
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub text {
  ### a
  my $self = shift;
  $Text_of{$self} = shift if @_;
  return $Text_of{$self};
}

sub display {
  my $self = shift;
  return $self->text;
}

sub DESTROY {
  my $self = shift;
  delete $Type_of{$self};
  delete $Text_of{$self};
  delete $Name_of{$self};
}

}

1;
