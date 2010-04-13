package EnsEMBL::Web::Factory::Marker;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self      = shift;    
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;
  
  my $marker    = $self->param('m');
     $marker    =~ s/\s//g;
  return $self->problem( 'Fatal', 'Valid Marker ID required', "Please enter a valid marker ID in the URL. " ) unless $marker;

  my $marker_adaptor  = $database->get_MarkerAdaptor();
  my $markers         = $marker_adaptor->fetch_all_by_synonym($marker);
  my @markers         = grep { $_ } @{$markers||[]};
  
  return $self->problem( 'Fatal', "Could not find Marker $marker",
    "Either $marker does not exist in the current Ensembl database, or there was a problem retrieving it." ) unless @markers;

  $self->DataObjects(map { $self->new_object( 'Marker', $_, $self->__data ) } @markers );
}

1;
  
