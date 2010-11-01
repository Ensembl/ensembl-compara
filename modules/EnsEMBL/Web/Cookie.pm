package EnsEMBL::Web::Cookie;
use CGI::Cookie;
use strict;

sub new {
  my ($class, $args) = @_;
  my $self = {
    'host'  => undef,
    'name'  => undef,
    'value' => undef,
    'env'   => undef,
    'hash'  => undef,
    %$args
  };
  bless $self, $class;
  return $self;
}

sub get_host { return $_[0]->{'host'}; }
sub set_host { $_[0]->{'host'} = $_[1]; }

sub get_name { return $_[0]->{'name'}; }
sub set_name { $_[0]->{'name'} = $_[1]; }

sub get_value { return $_[0]->{'value'}; }
sub set_value { $_[0]->{'value'} = $_[1]; }

sub get_env { return $_[0]->{'env'}; }
sub set_env { $_[0]->{'env'} = $_[1]; }

sub get_hash { return $_[0]->{'hash'}; }
sub set_hash { $_[0]->{'hash'} = $_[1]; }


sub clear {
  my( $self, $r ) = @_;
  return unless $r;
  $self->set_value( 0 );
  my $cookie = CGI::Cookie->new(
    -httponly => 1,
    -name    => $self->get_name,
    -value   => $self->encrypt_value(),
    -domain  => $self->get_host,
    -path    => "/",
    -expires => "Monday, 31-Dec-1970 23:59:59 GMT"
  );
  $r->headers_out->add(  'Set-cookie' => $cookie );
  $r->err_headers_out->add( 'Set-cookie' => $cookie );
  $r->subprocess_env->{ $self->get_env } = 0;
  $ENV{ $self->get_env } = 0;
}

sub create {
  my( $self, $r, $value ) = @_;
  return unless $r;
  $self->set_value( $value );
  my $cookie = CGI::Cookie->new(
    -httponly => 1,
    -name    => $self->get_name,
    -value   => $self->encrypt_value($self->get_value),
    -domain  => $self->get_host,
    -path    => "/",
    -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
  );
  $r->headers_out->add(     'Set-cookie' => $cookie );
  $r->err_headers_out->add( 'Set-cookie' => $cookie );
  $r->subprocess_env->{ $self->get_env } = $value;
  $ENV{ $self->get_env }                 = $value;
}

sub retrieve {
  my( $self, $r ) = @_;
  return unless $r;
  my %cookies = CGI::Cookie->parse($r->headers_in->{'Cookie'});
  return unless exists $cookies{$self->get_name};
  my( $ID, $flag ) = $self->decrypt_value( $cookies{$self->get_name}->value );
# warn "COOKIE $ID $flag";
  if( $flag eq 'expired' ) {      ## Remove the cookie!
    $self->clear();
  } elsif( $flag eq 'refresh' ) { ## Refresh the cookie
    $self->create( $ID );
  } else {                        ## OK just set value
    $self->set_value( $ID );
    $r->subprocess_env->{ $self->get_env } = $ID;
    $ENV{ $self->get_env }                 = $ID;
  }
}

sub encrypt_value {
  my $self = shift;
  my $hashref = $self->get_hash;
  my $ID = $self->get_value;

  my $rand1 = 0x8000000 + 0x7ffffff * rand();
  my $rand2 = ( $rand1 ^ ($ID + $hashref->{'offset'} ) ) & 0x0fffffff;
  my $time  = time() + 86400 * $hashref->{'expiry'};
  my $encrypted =
    crypt( sprintf("%08x",$rand1 ),$hashref->{'key1'}).
    crypt( sprintf("%08x",$time  ),$hashref->{'key2'}).
    crypt( sprintf("%08x",$rand2 ),$hashref->{'key3'});
  my $MD5d = Digest::MD5->new->add($encrypted)->hexdigest();
  return sprintf("%s%08x%08x%08x%s", substr($MD5d,0,16), $rand1, $time, $rand2, substr($MD5d,16,16) );
}

sub decrypt_value {
  my( $self, $string ) = @_;
  my $hashref = $self->get_hash;

  my $rand1  = substr($string,16,8);
  my $time   = substr($string,24,8);
  return(0,'expired') if(hex($time)<time());
  my $rand2  = substr($string,32,8);
  my $ID = ( ( hex( $rand1 ) ^ hex( $rand2 ) ) - $hashref->{'offset'} ) & 0x0fffffff;
  my $XXXX = crypt($rand1,$hashref->{'key1'}).
             crypt($time, $hashref->{'key2'}).
             crypt($rand2,$hashref->{'key3'});
  my $MD5d = Digest::MD5->new->add($XXXX)->hexdigest();
  return (
    (substr($MD5d,0,16).$rand1.$time.$rand2.substr($MD5d,16,16)) eq $string ? $ID : 0,
    hex($time) < time() - $hashref->{'refresh'} * 86400 ? 'refresh': 'ok' 
  );

}

1;
