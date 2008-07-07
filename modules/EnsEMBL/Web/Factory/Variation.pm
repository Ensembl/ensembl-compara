package EnsEMBL::Web::Factory::Variation;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects {
  my $self      = shift; 
  my $dbs= $self->get_databases(qw(core variation));
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $dbs;
  my $variation_db = $dbs->{'variation'};
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the variation database." ) unless $variation_db;
  $variation_db->dnadb($dbs->{'core'});

   my $variation    = $self->param('variation')|| $self->param('v');
   my $source = $self->param('source');
   return $self->problem( 'Fatal', 'Variation feature ID required', "A Variation feature ID is required to build this page." ) unless $variation;

   my $vari_adaptor = $variation_db->get_VariationAdaptor;
   my $variation_obj     = $vari_adaptor->fetch_by_name( $variation, $source);

   return $self->problem( 'Fatal', "Could not find Variation feature $variation",
     "Either $variation does not exist in the current Ensembl database, or there was a problem retrieving it." ) unless $variation_obj;
  my $obj = EnsEMBL::Web::Proxy::Object->new( 'Variation', $variation_obj, $self->__data );
   $self->DataObjects($obj);
}

1;
