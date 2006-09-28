package EnsEMBL::Web::Tools::Document::Method;

use strict;
use warnings;

{

my %Name_of;
my %Result_of;
my %Type_of;
my %Module_of;
my %Documentation_of;
my %Table_of;

sub new {
  ### c
  ### Inside-out class for representing Perl methods.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Name_of{$self} = defined $params{name} ? $params{name} : "";
  $Module_of{$self} = defined $params{module} ? $params{module} : "";
  $Documentation_of{$self} = defined $params{documentation} ? $params{documentation} : "";
  $Table_of{$self} = defined $params{table} ? $params{table} : {};
  $Type_of{$self} = defined $params{type} ? $params{type} : "unknown";
  $Result_of{$self} = defined $params{result} ? $params{result} : "";
  return $self;
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub documentation {
  ### a
  my $self = shift;
  $Documentation_of{$self} = shift if @_;
  return $Documentation_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub result {
  ### a
  my $self = shift;
  $Result_of{$self} = shift if @_;
  return $Result_of{$self};
}

sub module {
  ### a
  my $self = shift;
  $Module_of{$self} = shift if @_;
  return $Module_of{$self};
}

sub table {
  ### a
  my $self = shift;
  $Table_of{$self} = shift if @_;
  return $Table_of{$self};
}

sub package {
  ### Convenience accessor pointing to module object
  return module(@_);
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Name_of{$self};
  delete $Documentation_of{$self};
  delete $Type_of{$self};
  delete $Result_of{$self};
  delete $Module_of{$self};
  delete $Table_of{$self};
}

}

1;
