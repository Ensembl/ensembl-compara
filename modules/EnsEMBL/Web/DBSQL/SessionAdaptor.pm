package EnsEMBL::Web::DBSQL::SessionAdaptor;

use Class::Std;
use EnsEMBL::Web::Session;
use Digest::MD5;
use strict;
use CGI::Cookie;
{
  my %DBAdaptor_of   :ATTR( :name<db_adaptor>   );
  my %SpeciesDefs_of :ATTR( :name<species_defs> );
#  my %Memcache_of    :ATTR( :name<memcache>     );

  sub get_session_from_cookie {
    my( $self, $arg_ref ) = @_;
    $arg_ref->{'cookie'}->retrieve($arg_ref->{'r'});
    return EnsEMBL::Web::Session->new({
      'adaptor'      => $self,
      'cookie'       => $arg_ref->{'cookie'},
      'session_id'   => $arg_ref->{'cookie'}->get_value,
      'species_defs' => $self->get_species_defs,
      'species'      => $arg_ref->{'species'}
    });
  }

  sub get_session_by_id {
    my( $self, $arg_ref ) = @_;
    return EnsEMBL::Web::Session->new({
      'adaptor'      => $self,
      'cookie'       => undef,
      'session_id'   => $arg_ref->{'ID'},
      'species_defs' => $self->get_species_defs,
      'species'      => $arg_ref->{'species'},
    });
  }

  sub create_session_id {
### If not defined get new session id, and create cookie! must be done before any output is
### handled!
    my(  $self, $r, $cookie ) = @_;
#-- No db connection so return - can't create session...
warn "CREATING SESSION.... ";
    return 0 unless( $self->get_db_adaptor );
#-- Increment last_session_no in db and return value!
    $self->get_db_adaptor->do("lock tables session write");
    my($session_id) = $self->get_db_adaptor->selectrow_array("select last_session_no from session");
    if($session_id) {
      $self->get_db_adaptor->do("update session set last_session_no = ?",{}, ++$session_id );
    } else {
#      $self->get_db_adaptor->do("truncate session");
      $session_id = 1;
      $self->get_db_adaptor->do("insert into session set last_session_no = ?",{}, $session_id);
    }
    $self->get_db_adaptor->do("unlock tables");
#-- Create cookie and set the subprocess environment variable ENSEMBL_FIRSTSESSION;
#warn "  ## Creating new user session $session_id";
    if( $r ) { # We have an apache request object yeah!
#warn "  `-- storing cookie...";
      $cookie->create( $r, $session_id );
    }
    return $session_id;
  }

sub clearCookie {
### Clear (expire the cookie)
### We need to delete all entries in the session_record table!!
  my(  $self, $r, $session ) = @_;
  return unless $session->get_session_id;
  $self->get_db_adaptor->do("delete from session_record where session_id = ?", {}, $session->get_session_id);
  if( $r ) {
    $session->get_cookie->clear( $r );
  }
}

sub setConfigByName {
  my( $self, $session_id, $type, $key, $value ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  #warn "========> SETTING CONFIG";
  return $self->setConfig( $session_id, $type, $key, $value );
}

sub resetConfigByName {
  my( $self, $session_id, $type, $key ) = @_;
  return unless($type && $self->get_db_adaptor && $session_id > 0 );
  $self->get_db_adaptor->do( "delete from session_record where session_id = ? and type = ? and code = ?", {}, $session_id, $type, $key );
}

sub getConfigsByType {
  my( $self, $session_id, $type ) = @_;
  return unless($type && $self->get_db_adaptor && $session_id > 0 );
  my %configs = map {($_->[0]=>$_->[1])} @{$self->get_db_adaptor->selectall_arrayref( "select code, data from session_record where session_id = ? and type = ?", {}, $session_id, $type )||{}};
  return \%configs;
}

sub getConfigByName {
  my( $self, $session_id, $type, $key ) = @_;
  return unless($type && $self->get_db_adaptor && $session_id > 0 );
  my( $value ) = $self->get_db_adaptor->selectrow_array( "select data from session_record where session_id = ? and type = ? and code = ?", {}, $session_id, $type, $key );
  return $value;
}

sub setConfig {
### Set the session configuration to the specified value with session_id and type as passed
  my( $self, $session_id, $type, $key , $value ) = @_;
  #warn "=======> setConfig: SETTING CONFIG WITH: " . $value;
  return unless( $session_id && $type && $self->get_db_adaptor );
  my($now) = $self->get_db_adaptor->selectrow_array( "select now()" );
  my $rows = $self->get_db_adaptor->do(
    "insert ignore into session_record
        set created_at = ?, modified_at = ?, data = ?, session_id = ?, type = ?, code = ?",{},
    $now, $now, $value, $session_id, $type, $key
  );
  if( $rows && $rows < 1 ) {
    #warn "=======> setConfig: UPDATING ID: " . $session_id;
    $self->get_db_adaptor->do(
      "update session_record set data = ?, modified_at = ?
        where session_id = ? and type = ? and code = ?", {}, 
      $value, $now, $session_id, $type, $key 
    );
  }
  return $session_id;
}

sub getConfig {
### Get the session configuration with session_id and type as passed
  my( $self,$session_id,$type, $key ) = @_;
  return unless( $session_id && $type && $self->get_db_adaptor );
  my( $value ) = $self->get_db_adaptor->selectrow_array(
    "select data from session_record
      where session_id = ? and type = ? and code = ?", {},
    $session_id, $type, $key 
  );
  return $value;
}

sub resetConfig {
### Reset the session configuration with session_id and type as passed
  my( $self, $session_id, $type, $key ) = @_;
  return unless( $type && $self->get_db_adaptor && $session_id > 0 );
  $self->get_db_adaptor->do(
    "delete from session_record
      where session_id = ? and type = ? and code = ?", {},
    $session_id, $type, $key
  );
}

}

1;
