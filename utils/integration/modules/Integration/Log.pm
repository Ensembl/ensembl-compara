package Integration::Log;

use strict;
use warnings;

{

my %Log_of;
my %Date_of;

sub new {
  ### Inside-out base class for logging integration runs
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Date_of{$self} = defined $params{date} ? $params{date} : "";
  $Log_of{$self} = undef; 
  return $self;
}

sub date {
  ### a
  my $self = shift;
  $Date_of{$self} = shift if @_;
  return $Date_of{$self};
}

sub log {
  ### a
  my $self = shift;
  $Log_of{$self} = shift if @_;
  return $Log_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Log_of{$self};
  delete $Date_of{$self};
}

}

1;
