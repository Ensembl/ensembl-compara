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
}

1;
  
