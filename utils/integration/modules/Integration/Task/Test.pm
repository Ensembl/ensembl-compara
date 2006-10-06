package Integration::Task::Test;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

my %Errors_of;
my %Target_of;
my %Name_of;
my %Criticality_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Errors_of{$self} = defined $params{errors} ? $params{errors} : [];
  $Target_of{$self} = defined $params{target} ? $params{target} : [];
  $Name_of{$self} = defined $params{name} ? $params{name} : [];
  $Criticality_of{$self} = defined $params{critical} ? $params{critical} : "no";
  return $self;
}

sub did_fail {
  my $self = shift;
  my @errors = @{ $self->errors };
  return $#errors + 1;
}

sub errors {
  ### a
  my $self = shift;
  $Errors_of{$self} = shift if @_;
  return $Errors_of{$self};
}

sub add_error {
  my ($self, $error) = @_;
  push @{ $self->errors }, $error;
}

sub reset_errors {
  my $self = shift;
  $self->errors([]);
}

sub target {
  ### a
  my $self = shift;
  $Target_of{$self} = shift if @_;
  return $Target_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub critical {
  ### a
  my $self = shift;
  $Criticality_of{$self} = shift if @_;
  return $Criticality_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Errors_of{$self};
  delete $Target_of{$self};
  delete $Name_of{$self};
  delete $Criticality_of{$self};
}

}

1;
