package EnsEMBL::Web::DBSQL::SessionAdaptor;

use Class::Std;
use EnsEMBL::Web::Session;
use Digest::MD5;
use strict;
use CGI::Cookie;
{
  my %DBAdaptor_of   :ATTR( :name<db_adaptor>   );
  my %SpeciesDefs_of :ATTR( :name<species_defs> );

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
    return 0 unless( $self->get_db_adaptor );
#-- Increment last_session_no in db and return value!
    $self->get_db_adaptor->do("lock tables session write");
    my($session_id) = $self->get_db_adaptor->selectrow_array("select last_session_no from session");
    if($session_id) {
      $self->get_db_adaptor->do("update session set last_session_no = ?",{}, ++$session_id );
    } else {
      $self->get_db_adaptor->do("truncate session");
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
  $self->get_db_adaptor->do("delete from session_record where session_id ?", {}, $session->get_session_id);
  if( $r ) {
    $session->get_cookie->clear( $r );
  }
}

sub setConfigByName {
  my( $self, $session_id, $type, $key, $value ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $type_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {},  $type );
  unless( $type_id ) {
    $self->get_db_adaptor->do( "insert ignore into type set code = ?", {}, $type );
    ( $type_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $type );
  }
  #warn "========> SETTING CONFIG";
  return $self->setConfig( $session_id, $type_id, $key, $value );
}

sub resetConfigByName {
  my( $self, $session_id, $type, $key ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $type_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $type );
  return unless $type_id;
  $self->get_db_adaptor->do( "delete from session_record where session_id = ? and type_id = ? and code = ?", {}, $session_id, $type_id, $key );
}

sub getConfigsByType {
  my( $self, $session_id, $type ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $type_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $type );
  return unless $type_id;
  my %configs = map {($_->[0]=>$_->[1])} @{$self->get_db_adaptor->selectall_arrayref( "select code, data from session_record where session_id = ? and type_id = ?", {}, $session_id, $type_id )||{}};
  return \%configs;
}

sub getConfigByName {
  my( $self, $session_id, $type, $key ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $type_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $type );
  return unless $type_id;
  my( $value ) = $self->get_db_adaptor->selectrow_array( "select data from session_record where session_id = ? and type_id = ? and code = ?", {}, $session_id, $type_id, $key );
  return $value;
}

sub setConfig {
### Set the session configuration to the specified value with session_id and type_id as passed
  my( $self, $session_id, $type_id, $key , $value ) = @_;
  #warn "=======> setConfig: SETTING CONFIG WITH: " . $value;
  return unless( $session_id && $type_id && $self->get_db_adaptor );
  my $rows = $self->get_db_adaptor->do(
    "insert ignore into session_record
        set created_at = now(), modified_at = now(), data = ?, session_id = ?, type_id = ?, code = ?",{},
    $value, $session_id, $type_id, $key
  );
  if( $rows && $rows < 1 ) {
    #warn "=======> setConfig: UPDATING ID: " . $session_id;
    $self->get_db_adaptor->do(
      "update session_record set data = ?, modified_at = now()
        where session_id = ? and type_id = ? and code = ?", {}, 
      $value, $session_id, $type_id, $key 
    );
  }
  return $session_id;
}

sub getConfig {
### Get the session configuration with session_id and type_id as passed
  my( $self,$session_id,$type_id, $key ) = @_;
  return unless( $session_id && $type_id && $self->get_db_adaptor );
  my( $value ) = $self->get_db_adaptor->selectrow_array(
    "select data from session_record
      where session_id = ? and type_id = ? and code = ?", {},
    $session_id, $type_id, $key 
  );
  return $value;
}

sub resetConfig {
### Reset the session configuration with session_id and type_id as passed
  my( $self, $session_id, $type_id, $key ) = @_;
  my $session_id      = shift;
  my $type_id = shift;
  return unless( $type_id > 0 && $self->get_db_adaptor && $session_id > 0 );
  $self->get_db_adaptor->do(
    "delete from session_record
      where session_id = ? and type_id = ? and code = ?", {},
    $session_id, $type_id, $key
  );
}

}

1;
