package EnsEMBL::Web::DBSQL::UserDBAdaptor;
use strict;
use Class::Std;
use base qw(EnsEMBL::Web::DBSQL::DBAdaptor);
use Carp;

{
  sub connection_details {
    my( $self, $arg_ref ) = @_;

    return {
      'name' => $arg_ref->{'species_defs'}->ENSEMBL_USERDB_NAME,
      'host' => $arg_ref->{'species_defs'}->ENSEMBL_USERDB_HOST,
      'port' => $arg_ref->{'species_defs'}->ENSEMBL_USERDB_PORT,
      'user' => $arg_ref->{'species_defs'}->ENSEMBL_USERDB_USER,
      'pass' => $arg_ref->{'species_defs'}->ENSEMBL_USERDB_PASS,
    };
  }
}

1;
