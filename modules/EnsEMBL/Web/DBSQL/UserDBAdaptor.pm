package EnsEMBL::Web::DBSQL::UserDBAdaptor;
use Class::Std;
use Carp;
use strict;

{
  my %DBHandle_of :ATTR( :get<dbhandle> :set<dbhandle> );

  sub BUILD {
### connect to the database and store the database handle...
    my( $self, $ident, $arg_ref ) = @_;
    $DBHandle_of{ $ident } = DBI->connect(
      join( ':', 'dbi', 'mysql',
        $arg_ref->{'species_defs'}->ENSEMBL_USERDB_NAME,
        $arg_ref->{'species_defs'}->ENSEMBL_USERDB_HOST,
        $arg_ref->{'species_defs'}->ENSEMBL_USERDB_PORT
      ),
      $arg_ref->{'species_defs'}->ENSEMBL_USERDB_USER,
      $arg_ref->{'species_defs'}->ENSEMBL_USERDB_PASS,
      {RaiseError=>1,PrintError=>0}
    );
  }

  sub disconnect {
### wrapper around DBI;
    my $self = shift;
    $self->get_dbhandle->disconnect();
  }
  sub selectrow_array {
### wrapper around DBI
    my $self = shift;
    $self->get_dbhandle->selectrow_array( @_ );
  }

  sub selectrow_arrayref {
### wrapper around DBI
    my $self = shift;
    $self->get_dbhandle->selectrow_arrayref( @_ );
  }

  sub selectall_arrayref {
### wrapper around DBI
    my $self = shift;
    $self->get_dbhandle->selectall_arrayref( @_ );
  }

  sub do {
### wrapper around DBI
    my $self = shift;
    $self->get_dbhandle->do( @_ );
  }

  sub prepare {
### wrapper around DBI
    my $self = shift;
    $self->get_dbhandle->prepare( @_ );
  }

  sub carp {
### "carp" the query - with ?'s interpolated...
    my $self = shift;
    my $q = shift;
    shift;
    foreach(@_) {
      $q=~s/\?/'$_'/;
    }
    carp( "Query:\n----------\n$q\n----------" );
  }

}
1;
