package EnsEMBL::Web::Factory::Marker;

# my $factory  = EnsEMBL::Web::Proxy::Factory->new( 'Marker', $input->options, $dbs );
#    $factory->createObjects(); 

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self      = shift;    
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;
  
  my $marker    = $self->param('marker');
     $marker    =~ s/\s//g;
  return $self->problem( 'Fatal', 'No Marker ID', "A marker ID is required to build the markview page." ) unless $marker;

  my $marker_adaptor  = $database->get_MarkerAdaptor();
  my $markers         = $marker_adaptor->fetch_all_by_synonym($marker);
  my @markers         = grep { $_ } @{$markers||[]};
  
  return $self->problem( 'Fatal', "Could not find Marker $marker",
    "Either $marker does not exist in the current Ensembl database, or there was a problem retrieving it." ) unless @markers;

  $self->DataObjects(map { EnsEMBL::Web::Proxy::Object->new( 'Marker', $_, $self->__data ) } @markers );
}

1;
  
