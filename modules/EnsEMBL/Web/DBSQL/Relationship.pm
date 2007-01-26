package EnsEMBL::Web::DBSQL::Relationship;

use strict;
use warnings;

{

my %Type_of;
my %FromTable_of;
my %ToTable_of;
my %OptionColumns_of;
my %OptionOrder_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Type_of{$self}           = defined $params{type} ? $params{type} : "";
  $FromTable_of{$self}      = defined $params{from} ? $params{from} : "";
  $ToTable_of{$self}        = defined $params{to} ? $params{to} : "";
  $OptionColumns_of{$self}  = defined $params{option_columns} ? $params{option_columns} : [];
  $OptionOrder_of{$self}    = defined $params{option_order} ? $params{option_order} : '';
  return $self;
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub from {
  ### a
  my $self = shift;
  $FromTable_of{$self} = shift if @_;
  return $FromTable_of{$self};
}

sub to {
  ### a
  my $self = shift;
  $ToTable_of{$self} = shift if @_;
  return $ToTable_of{$self};
}

sub option_columns {
  ### a
  my $self = shift;
  $OptionColumns_of{$self} = shift if @_;
  return $OptionColumns_of{$self};
}

sub option_order {
  ### a
  my $self = shift;
  $OptionOrder_of{$self} = shift if @_;
  return $OptionOrder_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Type_of{$self};
  delete $FromTable_of{$self};
  delete $ToTable_of{$self};
  delete $OptionColumns_of{$self};
  delete $OptionOrder_of{$self};
}
 
}

1;
