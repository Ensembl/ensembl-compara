package EnsEMBL::Web::Data::Bio;

### NAME: EnsEMBL::Web::Data::Bio
### Base class - wrapper around a Bio::EnsEMBL API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object

### DESCRIPTION:
### This module and its children provide additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data);

sub _init {
  my $self = shift;
  $self->data_objects(@_);
}

sub convert_to_drawing_parameters {
### Stub - individual object types probably need to implement this separately
  my $self = shift;
  return [];
}

sub coord_systems {
  my $self = shift;
  return [map { $_->name } @{ $self->hub->database('core')->get_CoordSystemAdaptor()->fetch_all() }];
}

1;
