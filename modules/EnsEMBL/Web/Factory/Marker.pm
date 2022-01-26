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

package EnsEMBL::Web::Factory::Marker;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self     = shift;    
  my $database = $self->database('core');
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $database;
  
  my $marker = $self->param('m') || $self->param('marker');
     $marker =~ s/\s//g;
     
  return $self->problem('fatal', 'Valid Marker ID required', 'Please enter a valid marker ID in the URL.') unless $marker;
  
  my @markers = grep $_, @{$database->get_MarkerAdaptor->fetch_all_by_synonym($marker) || []};
  
  return $self->problem('fatal', "Could not find Marker $marker", "Either $marker does not exist in the current Ensembl database, or there was a problem retrieving it.") unless @markers;
  
  $self->DataObjects($self->new_object('Marker', \@markers, $self->__data));
  
  $self->param('m', $marker);
  $self->delete_param('marker');
}

1;
  
