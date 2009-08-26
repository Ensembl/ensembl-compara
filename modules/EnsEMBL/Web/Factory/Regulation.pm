package EnsEMBL::Web::Factory::Regulation;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(  EnsEMBL::Web::Factory );

use EnsEMBL::Web::Proxy::Object;
use CGI qw(escapeHTML);

sub _help {

  return;
}

sub createObjects {
  my $self      = shift;
  my $dbh     = $self->species_defs->databases->{'DATABASE_FUNCGEN'};

 return $self->problem ('Fatal', 'Database Error', "There is no functional genomics database for this species.") unless $dbh;

  if( $self->core_objects->regulation ) {
    $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Regulation', $self->core_objects->regulation, $self->__data ));
    return;
  }

  my $dbs= $self->get_databases(qw(core funcgen));
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $dbs;
  my $funcgen_db = $dbs->{'funcgen'};
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the functional genomics database." ) unless $funcgen_db;

  my $reg_feat = $self->param('rf');
  return $self->problem( 'Fatal', 'Regulatory Feature ID required',$self->_help( "A regulatory feature ID is required to build this page.") ) unless $reg_feat;

  my $rf_adaptor = $funcgen_db->get_RegulatoryFeatureAdaptor;
  my $reg_feat_obj = $rf_adaptor->fetch_by_stable_id( $reg_feat);

  return $self->problem( 'Fatal', "Could not find regulatory feature $reg_feat",
    $self->_help( "Either $reg_feat does not exist in the current Ensembl database, or there was a problem retrieving it.")
  ) unless $reg_feat_obj;

  $self->problem( 'redirect', $self->_url({'fdb'=>'funcgen','rf'=>$reg_feat,'v'=>undef, 'pt' =>undef,'g'=>undef,'r'=>undef,'t'=>undef}));
  return;
  my $obj = EnsEMBL::Web::Proxy::Object->new( 'Regulaiton', $reg_feat_obj, $self->__data );
   $self->DataObjects($obj);
}

1;

