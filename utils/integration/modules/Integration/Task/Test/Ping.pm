package Integration::Task::Test::Ping;

use strict;
use warnings;

use Integration::Task::Test;
our @ISA = qw(Integration::Task::Test);

{

my %Proxy_of;
my %Search_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Proxy_of{$self} = defined $params{proxy} ? $params{proxy} : "";
  $Search_of{$self} = defined $params{search} ? $params{search} : "";
  return $self;
}

sub process {
  ### Pings the server and checks for a live Ensembl site. 
  my $self = shift;
  $self->reset_errors;
  $ENV{http_proxy} = $self->proxy;
  my $command = "wget -O - " . $self->target;
  my $response = `$command`;
  if ($response =~ $self->search) {
    return 1;
  } 
  $self->add_error("Server response was incorrect");
  return 0;
}

sub proxy {
  ### a
  my $self = shift;
  $Proxy_of{$self} = shift if @_;
  return $Proxy_of{$self};
}

sub search {
  ### a
  my $self = shift;
  $Search_of{$self} = shift if @_;
  return $Search_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Proxy_of{$self};
  delete $Search_of{$self};
}

}

1;
