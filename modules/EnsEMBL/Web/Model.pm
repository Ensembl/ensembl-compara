package EnsEMBL::Web::Model;

### NAME: EnsEMBL::Web::Model
### Base class for all ORM (object-relational mapping) data objects

### PLUGGABLE: No

### STATUS: Under Development

### DESCRIPTION:
### The Model component in the MVC framework, the children of this
### base module encapsulate the 'business' logic needed by webpages 
### in order to manipulate and display database content
### All Model objects contain a data object (mediated via an ORM)
### and a reference to the EnsEMBL::Web::Hub object

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Root);

sub new {
### c
  my ($class, $hub, $data) = @_;
  my $self = {
    '_hub'  => $hub,
    '_data' => $data,
  }
  bless $self, $class;
  return $self;
}

sub hub {
### a 
  return $_[0]->{'_hub'}; 
}

sub data  {
### a 
  return $_[0]->{'_data'}; 
}

1;
