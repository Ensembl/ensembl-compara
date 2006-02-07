package EnsEMBL::Web::Factory::SNP;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
##use Bio::EnsEMBL::Variation::DBSQL::VariationAdaptor;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects {
  my $self      = shift;
  my $dbs= $self->get_databases(qw(core variation));
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $dbs;
  $dbs->{'variation'}->dnadb($dbs->{'core'});

   my $snp    = $self->param('snp');
   my $source = $self->param('source');
   return $self->problem( 'Fatal', 'SNP ID required', "A SNP ID is required to build this page." ) unless $snp;

   my $vari_adaptor = $dbs->{'variation'}->get_VariationAdaptor;
   my $snp_obj     = $vari_adaptor->fetch_by_name( $snp, $source);
  
   return $self->problem( 'Fatal', "Could not find SNP $snp",
     "Either $snp does not exist in the current Ensembl database, or there was a problem retrieving it." ) unless $snp_obj;
  my $obj = EnsEMBL::Web::Proxy::Object->new( 'SNP', $snp_obj, $self->__data );
   $self->DataObjects($obj);
}

1;
