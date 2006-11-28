package EnsEMBL::Web::DBSQL::SessionAdaptor;

use Class::Std;
use EnsEMBL::Web::Session;
use Digest::MD5;
use strict;
use Apache::Cookie;
{
  my %DBAdaptor_of   :ATTR( :name<db_adaptor>   );
  my %SpeciesDefs_of :ATTR( :name<species_defs> );

  sub get_session_from_cookie {
    my( $self, $arg_ref ) = @_;
    $arg_ref->{'cookie'}->retrieve($arg_ref->{'request'});
    return EnsEMBL::Web::Session->new({
      'adaptor'      => $self,
      'cookie'       => $arg_ref->{'cookie'},
      'session_id'   => $arg_ref->{'cookie'}->get_value,
      'species_defs' => $self->get_species_defs,
      'input'        => $arg_ref->{'input'},
      'species'      => $arg_ref->{'species'},
      'exturl'       => $arg_ref->{'exturl'}
    });
  }

  sub get_session_by_id {
    my( $self, $arg_ref ) = @_;
    return EnsEMBL::Web::Session->new({
      'adaptor'      => $self,
      'cookie'       => undef,
      'session_id'   => $arg_ref->{'ID'},
      'species_defs' => $self->get_species_defs,
      'input'        => $arg_ref->{'input'},
      'request'      => $arg_ref->{'request'},
      'species'      => $arg_ref->{'species'},
      'exturl'       => $arg_ref->{'exturl'}
    });
  }

  sub create_session_id {
### If not defined get new session id, and create cookie! must be done before any output is
### handled!
    my $self            = shift;
    my $request         = shift;
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
    if( $request ) { # We have an apache request object yeah!
      my $cookie = Apache::Cookie->new(
        -name    => $self->species_defs->ENSEMBL_FIRSTSESSION_COOKIE,
        -value   => $self->encryptID($session_id),
        -domain  => $self->species_defs->ENSEMBL_COOKIEHOST,
        -path    => "/",
        -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
      );
      $self->{'_request'}->headers_out->add(     'Set-cookie' => $cookie );
      $self->{'_request'}->err_headers_out->add( 'Set-cookie' => $cookie );
      $self->{'_request'}->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = $session_id;
    }
    $ENV{'ENSEMBL_FIRSTSESSION'} = $session_id;
    return $session_id;
  }

sub clearCookie {
### Clear (expire the cookie)
### We need to delete all entries in the sessiondata table!!
  my $self = shift;
  my $r    = shift || $self->{'_request'};
  my $cookie = CGI::Cookie->new(
    -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_FIRSTSESSION_COOKIE,
    -value   => $self->encryptID(-1),
    -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
    -path    => "/",
    -expires => "Monday, 31-Dec-1970 23:59:59 GMT"
  );
  $self->get_db_adaptor->do("delete from sessiondata where session_id ?", {}, $self->{_session_id}) if $self->{_session_id};
  if( $r ) {
    $r->headers_out->add(     'Set-cookie' => $cookie );
    $r->err_headers_out->add( 'Set-cookie' => $cookie );
    $r->subprocess_env->{'ENSEMBL_FIRSTSESSION'} = 0;
  }
}

sub setConfigByName {
  my( $self, $r, $session_id, $key, $value ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $key_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {},  $key );
  unless( $key_id ) {
    $self->get_db_adaptor->do( "insert ignore into type set code = ?", {}, $key );
    ( $key_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $key );
  }
  return $self->setConfig( $r, $session_id, $key_id, $value );
}

sub clearConfigByName {
  my( $self, $session_id, $key ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $key_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $key );
  return unless $key_id;
  $self->get_db_adaptor->do( "delete from sessiondata where session_id = ? and type_id = ?", {}, $session_id, $key_id );
}

sub getConfigByName {
  my( $self, $session_id, $key ) = @_;
  return unless( $self->get_db_adaptor && $session_id > 0 );
  my( $key_id ) = $self->get_db_adaptor->selectrow_array( "select type_id from type where code = ?", {}, $key );
  return unless $key_id;
  my( $value ) = $self->get_db_adaptor->selectrow_array( "select value from sessiondata where session_id = ? and type_id = ?", {}, $session_id, $key_id );
  return $value;
}

sub setConfig {
### Set the session configuration to the specified value with session_id and type_id as passed
  my( $self, $r, $session_id, $sessiondatatype_id, $value ) = @_;
  return unless( $session_id && $sessiondatatype_id && $self->get_db_adaptor );
  my $rows = $self->get_db_adaptor->do(
    "insert ignore into sessiondata
        set updated = now(), value = ?, session_id = ?, type_id = ?",{},
    $value, $session_id, $sessiondatatype_id
  );
  if( $rows && $rows < 1 ) {
    $self->get_db_adaptor->do(
      "update sessiondata set value = ?, updated = now()
        where session_id = ? and type_id = ?", {}, 
      $value, $session_id, $sessiondatatype_id
    );
  }
  return $session_id;
}

sub getConfig {
### Get the session configuration with session_id and type_id as passed
  my( $self,$session_id,$sessiondatatype_id ) = @_;
  return unless( $session_id && $sessiondatatype_id && $self->get_db_adaptor );
  my( $value ) = $self->get_db_adaptor->selectrow_array(
    "select value from sessiondata
      where session_id = ? and type_id = ?", {},
    $session_id, $sessiondatatype_id 
  );
  return $value;
}

sub resetConfig {
### Reset the session configuration with session_id and type_id as passed
  my $self            = shift;
  my $session_id      = shift;
  my $sessiondatatype_id = shift;
  return unless( $sessiondatatype_id > 0 && $self->get_db_adaptor && $session_id > 0 );
  $self->get_db_adaptor->do(
    "delete from sessiondata
      where session_id = ? and type_id = ?", {},
    $session_id, $sessiondatatype_id
  );
}

}

1;
