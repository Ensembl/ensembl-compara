package EnsEMBL::Web::DBSQL::DBAdaptor;
use Class::Std;
use Carp;
use strict;

{
  my %DBHandle_of :ATTR( :get<dbhandle> :set<dbhandle> );

  sub connection_details {
### return connection details string 
    warn "YOU MUST DEFINE THE CONFIGURATION...";
    return {
      'name' => undef, 'host' => undef, 'port' => undef, 'user' => undef, 'pass' => undef
    };
  }
  sub BUILD {
### connect to the database and store the database handle...
    my( $self, $ident, $arg_ref ) = @_;
    my $conf = $self->connection_details( $arg_ref );
    $DBHandle_of{ $ident } = DBI->connect(
      join( ':', 'dbi', 'mysql', $conf->{'name'}, $conf->{'host'}, $conf->{'port'} ),
      $conf->{'user'}, $conf->{'pass'}, {RaiseError=>1,PrintError=>0}
    );
    $DBHandle_of{ $ident }{'mysql_auto_reconnect'} = 1;
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

  sub selectall_hashref {
### wrapper around DBI
    my $self = shift;
    $self->get_dbhandle->selectall_hashref( @_ );
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
