package EnsEMBL::Web::Data;

## NAME: EnsEMBL::Web::Data
### Base class for all domain objects 

### STATUS: Under development

### DESCRIPTION:
### The children of this base class encapsulate the 'business' logic needed 
### by webpages in order to manipulate and display database content
### All Data objects contain a reference to the EnsEMBL::Web::Hub object
### and to an ORM data object, either a Bio::EnsEMBL API object or an
### EnsEMBL::Data object

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Root);

sub new {
### c
  my $class = shift;
  my $hub = shift;

  my $self = {'_hub'  => $hub, '_data' => []};

  ## Set type automatically from class name
  my @A = split('::', $class);
  $self->{'_type'} = $A[-1];

  bless $self, $class;

  $self->_init(@_);

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

sub _init {}

sub data_objects {
### a
  my $self = shift;
  push @{$self->{'_data'}}, @_;
  return $self->{'_data'};
}

1;
