package EnsEMBL::Web::DBSQL::SQL::Result;

use strict;
use warnings;

our @ISA = qq(EnsEMBL::Web::DBSQL::SQL);

{

my %Result_of;
my %SetParameters_of;
my %Action_of;
my %LastInsertedId_of;
my %Success_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Result_of{$self}          = defined $params{result} ? $params{result} : undef;
  $Action_of{$self}          = defined $params{action} ? $params{action} : undef;
  $SetParameters_of{$self}          = defined $params{set_parameters} ? $params{set_parameters} : {};
  $LastInsertedId_of{$self}          = defined $params{last_inserted_id} ? $params{last_inserted_id} : "";
  $Success_of{$self}          = defined $params{success} ? $params{success} : undef;
  return $self;
}

sub result {
  ### a
  my $self = shift;
  $Result_of{$self} = shift if @_;
  return $Result_of{$self};
}

sub success {
  ### a
  my $self = shift;
  $Success_of{$self} = shift if @_;
  return $Success_of{$self};
}

sub set_parameters {
  ### a
  my $self = shift;
  $SetParameters_of{$self} = shift if @_;
  return $SetParameters_of{$self};
}

sub action {
  ### a
  my $self = shift;
  $Action_of{$self} = shift if @_;
  return $Action_of{$self};
}

sub last_inserted_id{
  ### a
  my $self = shift;
  $LastInsertedId_of{$self} = shift if @_;
  return $LastInsertedId_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Result_of{$self};
  delete $SetParameters_of{$self};
  delete $Action_of{$self};
  delete $LastInsertedId_of{$self};
  delete $Success_of{$self};
}

}

1;
