package EnsEMBL::Web::Tools::PluginLocator;

use strict;
use warnings;

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);

{

my %Children_of;
my %Locations_of;
my %Suffix_of;
my %Method_of;
my %Results_of;
my %Parameters_of;

sub new {
  ### c
  ### Inside-out class for finding plugin modules
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Children_of{$self} = [];
  $Locations_of{$self} = defined $params{locations} ? $params{locations} : [];
  $Suffix_of{$self} = defined $params{suffix} ? $params{suffix} : "";
  $Method_of{$self} = defined $params{method} ? $params{method} : "";
  $Results_of{$self} = undef;
  $Parameters_of{$self} = defined $params{parameters} ? $params{parameters} : [];
  return $self;
}

sub include {
  my $self = shift;
  my $success = 1;
  foreach my $module (@{ $self->locations }) {
    $module .= "::" . $self->suffix;
    warn "ADDING: " . $module;
    if ($self->dynamic_use($module)) {
      $self->add_child($module);
    } else {
      $success = 0;
    }
  }
  return $success;
}

sub create_all {
  my $self = shift;
  foreach my $child (@{ $self->children }) {
    my $temp = new $child;
   # warn "TEMP: " . $temp;
    $self->add_result($child, $temp);
  }
  return $self->results;
}

sub call {
  my ($self, @methods) = @_;
  my %results = ();
  foreach my $child (@{ $self->children }) {
    foreach my $method (@methods) {
      if ($child->can($method)) {
        $self->add_result($child, $child->$method( @{ $self->parameters } ) );
      }
    } 
  }
  return $self->results;
}

sub add_result {
  my ($self, $key, $result) = @_;
  if (!$self->results) {
    $self->results({});
  }
  $self->results->{$key} = $result;
}

sub result_for {
  my ($self, $key) = @_;
  return $self->results->{$key};
}

sub add_child {
  my ($self, $child) = @_;
  push @{ $self->children }, $child;
}

sub children {
  ### a
  my $self = shift;
  $Children_of{$self} = shift if @_;
  return $Children_of{$self};
}

sub results {
  ### a
  my $self = shift;
  $Results_of{$self} = shift if @_;
  return $Results_of{$self};
}

sub locations {
  ### a
  my $self = shift;
  $Locations_of{$self} = shift if @_;
  return $Locations_of{$self};
}

sub suffix {
  ### a
  my $self = shift;
  $Suffix_of{$self} = shift if @_;
  return $Suffix_of{$self};
}

sub method {
  ### a
  my $self = shift;
  $Method_of{$self} = shift if @_;
  return $Method_of{$self};
}

sub parameters {
  ### a
  my $self = shift;
  $Parameters_of{$self} = shift if @_;
  return $Parameters_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Children_of{$self};
  delete $Locations_of{$self};
  delete $Suffix_of{$self};
  delete $Method_of{$self};
  delete $Parameters_of{$self};
}

} 

1;
