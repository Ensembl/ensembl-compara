package EnsEMBL::Web::Factory::Variation;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

use base qw(  EnsEMBL::Web::Factory );

sub createObjects {
  my $self      = shift;
  if( $self->core_objects->variation ) {
    $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Variation', $self->core_objects->variation, $self->__data ));
    return;
  }

  my $dbs= $self->get_databases(qw(core variation));
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $dbs;
  my $variation_db = $dbs->{'variation'};
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the variation database." ) unless $variation_db;
  $variation_db->dnadb($dbs->{'core'});

  my $snp    = $self->param('snp') || $self->param('v');
  my $source = $self->param('source');
  return $self->problem( 'Fatal', 'SNP ID required', "A SNP ID is required to build this page." ) unless $snp;

  my $vari_adaptor = $variation_db->get_VariationAdaptor;
  my $snp_obj     = $vari_adaptor->fetch_by_name( $snp, $source);

  return $self->problem( 'Fatal', "Could not find SNP $snp",
   "Either $snp does not exist in the current Ensembl database, or there was a problem retrieving it." ) unless $snp_obj;

  $self->problem( 'redirect', $self->_url({'vdb'=>'variation','v'=>$snp, 'pt' =>undef,'g'=>undef,'r'=>undef,'t'=>undef}));
  return;
  my $obj = EnsEMBL::Web::Proxy::Object->new( 'SNP', $snp_obj, $self->__data );
   $self->DataObjects($obj);
}

1;
