=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
