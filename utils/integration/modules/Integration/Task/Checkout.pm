package Integration::Task::Checkout;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

my %Repository_of;
my %Name_of;
my %Root_of;
my %Username_of;
my %Protocol_of;
my %Modules_of;
my %Release_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Repository_of{$self} = defined $params{repository} ? $params{repository} : "";
  $Root_of{$self} = defined $params{root} ? $params{root} : "";
  $Username_of{$self} = defined $params{username} ? $params{username} : "";
  $Protocol_of{$self} = defined $params{protocol} ? $params{protocol} : "ext";
  $Modules_of{$self} = defined $params{modules} ? $params{modules} : [];
  $Name_of{$self} = defined $params{name} ? $params{name} : "checkout";
  $Release_of{$self} = defined $params{release} ? $params{release} : undef;
  return $self;
}

sub process {
  ### Performs a CVS checkout using the {{respository}}, {{root}}, {{username}} and {{protocol}} settings. 
  my $self = shift;

  my $start = new Benchmark;

  my @modules = @{ $self->modules };

  my $command = "cvs -d :" . $self->protocol . ":" . $self->username . "\@" . $self->repository . ":" . $self->root . " co -d " . $self->destination;
  if ($self->release) {
    $command .= " -r " . $self->release;
  }
  $command .= " @modules";
  warn "CVS: " . $command;

  my $location = $self->destination;
  my $logname = $self->name;
  $self->check_directory($location);
  
  my $cvs = `$command 2>$logname.log`;

  my $end = new Benchmark;
  $self->mark($start, $end);

  return 1;
}

sub repository {
  ### a
  my $self = shift;
  $Repository_of{$self} = shift if @_;
  return $Repository_of{$self};
}

sub root {
  ### a
  my $self = shift;
  $Root_of{$self} = shift if @_;
  return $Root_of{$self};
}

sub username {
  ### a
  my $self = shift;
  $Username_of{$self} = shift if @_;
  return $Username_of{$self};
}

sub protocol {
  ### a
  my $self = shift;
  $Protocol_of{$self} = shift if @_;
  return $Protocol_of{$self};
}

sub modules {
  ### a
  my $self = shift;
  $Modules_of{$self} = shift if @_;
  return $Modules_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub release {
  ### a
  my $self = shift;
  $Release_of{$self} = shift if @_;
  return $Release_of{$self};
}

sub add_module {
  my ($self, $module) = @_;
  push @{ $self->modules }, $module;
}

sub DESTROY {
  my $self = shift;
  delete $Repository_of{$self}; 
  delete $Root_of{$self}; 
  delete $Username_of{$self}; 
  delete $Protocol_of{$self}; 
  delete $Modules_of{$self}; 
  delete $Name_of{$self}; 
  delete $Release_of{$self}; 
}

}

1;
