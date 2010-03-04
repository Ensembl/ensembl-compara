package EnsEMBL::Web::Data::Bio;

### NAME: EnsEMBL::Web::Data::Bio
### Base class - wrapper around a Bio::EnsEMBL API object 

### PLUGGABLE: TODO 

### STATUS: Under Development

### DESCRIPTION:
### This module and its children provide additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data);


sub _init {
  my ($self, $args) = @_;

  ## Create API object from args
  $self->{'_api_object'} = $self->create_api_object($args);
}

sub create_api_object { ## Needs to be implemented in each child }

sub set_api_object { $_[0]->{'_api_object'} = $_[1]; }
sub get_api_object { return $_[0]->{'_api_object'}; }

1;

