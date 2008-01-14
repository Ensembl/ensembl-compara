package EnsEMBL::Web::DBSQL::WebDBAdaptor;

use Class::Std;
use base qw(EnsEMBL::Web::DBSQL::DBAdaptor);
use Carp;
use strict;

{
  sub connection_details {
    
    my( $self, $arg_ref ) = @_;
    return {
      'name' => $arg_ref->{'species_defs'}->multidb->{'ENSEMBL_WEBSITE'}{'NAME'},
      'host' => $arg_ref->{'species_defs'}->multidb->{'ENSEMBL_WEBSITE'}{'HOST'},
      'port' => $arg_ref->{'species_defs'}->multidb->{'ENSEMBL_WEBSITE'}{'PORT'},
      'user' => $arg_ref->{'species_defs'}->ENSEMBL_WRITE_USER,
      'pass' => $arg_ref->{'species_defs'}->ENSEMBL_WRITE_PASS,
    };
  }
}

1;
