=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::DBSQL::DBAdaptor;
use Carp;
use strict;

sub new {
  my( $class, $arg_ref ) = @_;
  my $self = {};

  ### connect to the database and store the database handle...
  my $conf = $self->connection_details( $arg_ref );
  if( exists( $conf->{'type'} ) && $conf->{'type'} eq 'sqlite' ) {
    $self->{'dbhandle'} = DBI->connect_cached(
      join( ':', 'dbi', 'SQLite', $conf->{'name'} )
    );
    $self->{'dbhandle'}->func( 'now', 0, sub { return time }, 'create_function' );
    $self->{'dbhandle'}->func( 'UNIX_TIMESTAMP', 1, sub { return $_[0] }, 'create_function' );
  } 
  else {
    $self->{'dbhandle'} = DBI->connect_cached(
      join( ':', 'dbi', 'mysql', $conf->{'name'}, $conf->{'host'}, $conf->{'port'} ),
      $conf->{'user'}, $conf->{'pass'}, {RaiseError=>1,PrintError=>0}
    );
    $self->{'dbhandle'}{'mysql_auto_reconnect'} = 1;
  }
  bless $self, $class;
  return $self;
}

sub dbhandle { return $_[0]->{'dbhandle'}; }

sub connection_details {
### return connection details string 
  warn "YOU MUST DEFINE THE CONFIGURATION...";
  return {
    'name' => undef, 'host' => undef, 'port' => undef, 'user' => undef, 'pass' => undef, 'type' => undef
  };
}

sub quote {
  my $self = shift;
  my $value = shift;
  return $self->dbhandle->quote($value);
}

sub disconnect {
### wrapper around DBI;
  my $self = shift;
  $self->dbhandle->disconnect();
}
  
sub selectrow_array {
### wrapper around DBI
  my $self = shift;
  $self->dbhandle->selectrow_array( @_ );
}

sub selectrow_arrayref {
### wrapper around DBI
  my $self = shift;
  $self->dbhandle->selectrow_arrayref( @_ );
}

sub selectall_arrayref {
### wrapper around DBI
  my $self = shift;
  $self->dbhandle->selectall_arrayref( @_ );
}

sub selectall_hashref {
### wrapper around DBI
  my $self = shift;
  #use Carp qw(cluck);
  #warn "SELECTALL HASHREF: " . cluck();
  $self->dbhandle->selectall_hashref( @_ );
}

sub selectrow_hashref {
### wrapper around DBI
  my $self = shift;
  #use Carp qw(cluck);
  #warn "SELECTROW HASHREF: " . cluck();
  $self->dbhandle->selectrow_hashref( @_ );
}

sub do {
### wrapper around DBI
  my $self = shift;
  $self->dbhandle->do( @_ );
}

sub prepare {
### wrapper around DBI
  my $self = shift;
  $self->dbhandle->prepare( @_ );
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

1;
