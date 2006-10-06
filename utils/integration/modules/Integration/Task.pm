package Integration::Task;

use strict;
use warnings;

use Benchmark;

{

my %Source_of;
my %Destination_of;
my %Benchmark_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Source_of{$self} = defined $params{source} ? $params{source} : "";
  $Destination_of{$self} = defined $params{destination} ? $params{destination} : "";
  $Benchmark_of{$self} = undef; 
  return $self;
}

sub mark {
  my ($self, $start, $end) = @_; 
  my $diff = timediff($end, $start);
  $self->benchmark(timestr($diff, 'all'));
}

sub source {
  ### a
  my $self = shift;
  $Source_of{$self} = shift if @_;
  return $Source_of{$self};
}

sub destination {
  ### a
  my $self = shift;
  $Destination_of{$self} = shift if @_;
  return $Destination_of{$self};
}

sub benchmark {
  ### a
  my $self = shift;
  $Benchmark_of{$self} = shift if @_;
  return $Benchmark_of{$self};
}

sub check_directory {
  my ($self, $dir) = @_;
  if (!-e $dir) {
    my $mk = `mkdir $dir`;
  }
}

sub DESTROY {
  my $self = shift;
  delete $Source_of{$self};
  delete $Destination_of{$self};
  delete $Benchmark_of{$self};
}

}

1;
