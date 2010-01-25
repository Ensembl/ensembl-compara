package EnsEMBL::Web::Model;

### NAME: EnsEMBL::Web::Model
### Base class for all ORM (object-relational mapping) data objects

### PLUGGABLE: No

### STATUS: Under Development

### DESCRIPTION:
### The Model component in the MVC framework, the children of this
### base module encapsulate the 'business' logic needed by webpages 
### in order to manipulate and display database content
### All Model objects contain a reference to the EnsEMBL::Web::Hub object
### and are either themselves an ORM data object or are a wrapper around
### such an object

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Root);

sub new {
### c
  my ($class, $hub, $args) = @_;

  ## Set type automatically from class name
  my @A = split('::', $class);
  $self->{'_type'} = $A[-1];

  my $self = {
    '_hub'  => $hub,
    '_type' => undef,
  }
  bless $self, $class;

  if ($args) {
    $self->_init($args);
  }

  return $self;
}

sub hub   {
### a
  my $self = shift;
  warn "GETTER ONLY - cannot dynamically set value of 'hub'" if @_; 
  return $self->{'_hub'}; 
} 

sub type  { 
### a
  my $self = shift;
  warn "GETTER ONLY - cannot dynamically set value of 'type'" if @_; 
  return $self->{'_type'}; 
} 

sub _init { ## Implement in child classes } 

1;
