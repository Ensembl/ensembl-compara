package EnsEMBL::Web::DBSQL::ColumnDef;

### Simple object to encapsulate a table column definition

use strict;
use warnings;

{

my %Type_of;
my %Null_of;
my %Key_of;
my %Default_of;
my %Extra_of;
my %ColumnOrder_of;

sub new {
  ### c
  my ($class, $params) = @_;
  my $self = bless \my($scalar), $class;
  $Type_of{$self}         = defined $params->{type} ? $params->{type} : '';
  $Null_of{$self}         = defined $params->{null} ? $params->{null} : '';
  $Key_of{$self}          = defined $params->{key} ? $params->{key} : '';
  $Default_of{$self}      = defined $params->{default} ? $params->{default} : '';
  $Extra_of{$self}        = defined $params->{extra} ? $params->{extra} : '';
  $ColumnOrder_of{$self}  = defined $params->{column_order} ? $params->{column_order} : undef;
  return $self;
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub null {
  ### a
  my $self = shift;
  $Null_of{$self} = shift if @_;
  return $Null_of{$self};
}

sub key {
  ### a
  my $self = shift;
  $Key_of{$self} = shift if @_;
  return $Key_of{$self};
}

sub default {
  ### a
  my $self = shift;
  $Default_of{$self} = shift if @_;
  return $Default_of{$self};
}

sub extra {
  ### a
  my $self = shift;
  $Extra_of{$self} = shift if @_;
  return $Extra_of{$self};
}

sub column_order {
  ### a
  my $self = shift;
  $ColumnOrder_of{$self} = shift if @_;
  return $ColumnOrder_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Type_of{$self};
  delete $Null_of{$self};
  delete $Key_of{$self};
  delete $Default_of{$self};
  delete $Extra_of{$self};
  delete $ColumnOrder_of{$self};
}

}

1;
