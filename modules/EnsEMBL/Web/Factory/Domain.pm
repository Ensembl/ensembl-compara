package EnsEMBL::Web::Factory::Domain;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self = shift;
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;

  my $domain_id = $self->param('domainentry') || $self->param('domain');
  return $self->problem( 'Fatal', 'No domain name supplied', "Please specify a valid domain name." ) unless $domain_id;
  my $domain;
  eval {
    $domain = $database->get_DBEntryAdaptor->fetch_by_db_accession('InterPro',$domain_id);
  };
  if( $@ || !$domain) {
    return $self->problem( 'Fatal', "Unknown domain", "The domain identifier you entered is not present in this species." );
  }
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Domain', $domain, $self->__data ) );
}

1;

