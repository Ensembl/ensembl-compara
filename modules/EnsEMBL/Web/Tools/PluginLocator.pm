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
my %Warnings_of;

sub new {
  ### c
  ### Inside-out class for finding and calling plugin modules.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Children_of{$self} = [];
  $Locations_of{$self} = defined $params{locations} ? $params{locations} : [];
  $Suffix_of{$self} = defined $params{suffix} ? $params{suffix} : "";
  $Method_of{$self} = defined $params{method} ? $params{method} : "";
  $Parameters_of{$self} = defined $params{parameters} ? $params{parameters} : [];
  $Warnings_of{$self} = undef
  $Results_of{$self} = undef;
  return $self;
}

sub include {
  ### Dynamically includes found modules in the locations specified by {{locations}}, ending in a specified (optional) suffix. Any previously loaded modules are not loaded again.
  ### Returns true even if modules failed to load. Anything calling
  ### {{include}} should check for {{warnings}} if it's important that
  ### a particular module is loaded.

  my $self = shift;
  my $success = 1;
  foreach my $module (@{ $self->locations }) {
    $module .= "::" . $self->suffix;
    if ($self->dynamic_use($module)) {
      $self->add_child($module);
    } else {
      if (!$self->warnings) {
        $self->warnings([]);
      }
      push @{ $self->warnings }, $self->dynamic_use_failure($module);
    }
  }
  return $success;
}

sub create_all {
  ### Creates an instance of each class found by {{include}}, and stores references to the objects in the {{results}} array.
  my $self = shift;
  foreach my $child (@{ $self->children }) {
    my $temp = $child->new( @_ );
    $self->add_result($child, $temp);
  }
  return $self->results;
}

sub call {
  ### Calls one or more methods on the classes found by {{include}}. The results are stored in the {{results}} array.
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
  ### Accepts a key value pair, and stores the value in the results hash against the key.
  my ($self, $key, $result) = @_;
  if (!$self->results) {
    $self->results({});
  }
  $self->results->{$key} = $result;
}

sub result_for {
  ### Returns a result from the {{result}} array for a particular class. If {{call}} has been called, this is the result of whatever methods were called against the class. If {{create_all}} has been called most recently, it will return the object reference for that class.
  my ($self, $key) = @_;
  return $self->results->{$key};
}

sub add_child {
  ### Adds a child to the {{children}} array.
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

sub warnings {
  ### a
  my $self = shift;
  $Warnings_of{$self} = shift if @_;
  return $Warnings_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Children_of{$self};
  delete $Locations_of{$self};
  delete $Suffix_of{$self};
  delete $Method_of{$self};
  delete $Parameters_of{$self};
  delete $Results_of{$self};
  delete $Warnings_of{$self};
}

} 

1;
