package EnsEMBL::Web::Interface::Tab;

use strict;
use warnings;

{

my %Name_of;
my %Label_of;
my %Content_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Name_of{$self}   = defined $params{name} ? $params{name} : "";
  $Label_of{$self}   = defined $params{label} ? $params{label} : "";
  $Content_of{$self}   = defined $params{content} ? $params{content} : "";
  return $self;
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub label {
  ### a
  my $self = shift;
  $Label_of{$self} = shift if @_;
  return $Label_of{$self};
}

sub content {
  ### a
  my $self = shift;
  $Content_of{$self} = shift if @_;
  return $Content_of{$self};
}

sub DESTROY {
  ### d
  my ($self) = shift;
  delete $Name_of{$self};
  delete $Label_of{$self};
  delete $Content_of{$self};
}


}

1;
