package Bio::Das::HTTP::Fetch;
# file: Fetch.pm
# $Id$

=head1 NAME

Bio::Das::HTTP::Fetch - Manage the HTTP protocol for DAS transactions

=head1 SYNOPSIS

 my $fetcher      = Bio::Das::HTTP::Fetch->new(
				    -request   => $request,
				    -headers   => {'Accept-encoding' => 'gzip'},
				    -proxy     => $proxy,
				    -norfcwarn => $nowarn,
                  );

 $fetcher->send_request();
 $fetcher->read();

 my $request          = $fetcher->request;
 my $socket           = $fetcher->socket;
 my $error            = $fetcher->error;
 my $url              = $fetcher->url;
 my $path             = $fetcher->path;
 my $outgoing_args    = $fetcher->outgoing_args;
 my $outgoing_headers = $fetcher->outgoing_headers;
 my $auth             = $fetcher->auth;
 my $incoming_header  = $fetcher->incoming_header;
 my $method           = $fetcher->method;

 my $protocol         = $fetcher->mode([$new_protocol]);
 my $status           = $fetcher->status([$new_status]);
 my $debug            = $fetcher->debug([$new_debug]);

 my ($protocol,$host,$port,$path,$user,$pass) = $fetcher->parse_url($url);

=head1 DESCRIPTION

This is a low-level class that is used for managing multiplexed
connections to DAS HTTP servers.  It is used internally by L<Bio::Das>
and it is unlikely that application programs will ever interact with
it directly.  The exception is when writing custom authentication
subroutines to fetch username/password information for
password-protected servers, in which case an L<Bio::Das::HTTP::Fetch>
is passed to the authentication subroutine.

=head2 METHODS

Following is a complete list of methods implemented by
Bio::Das::HTTP::Fetch.

=over 4

=cut


use strict;
use IO::Socket qw(:DEFAULT :crlf);
use Bio::Das::Util;
use Bio::Das::Request;
use MIME::Base64;  # For HTTP authenication encoding
use Carp 'croak';
use Errno 'EINPROGRESS','EWOULDBLOCK';
use vars '$VERSION';

$VERSION = '1.11';
my $ERROR = '';   # for errors that occur before we create the object

use constant READ_UNIT => 1024 * 5;  # 5K read units

=item $fetcher = Bio::Das::HTTP::Request->new(@args)

Create a new fetcher object.  At the time the object is created, it
will attempt to establish a non-blocking connection with the remote
server.  This means that the call to new() may be returned before the
connection is established.

Arguments are as follows:

  Name         Description
  ----         -----------

  -request     The Bio::Das::Request to run.

  -headers     A hashref containing additional
               headers to attach to the HTTP request.
               Typically used to enable data stream compression.

  -proxy       An HTTP proxy to use.

  -norfcwarn   Disable the warning that appears when the request
               contains username/password information attached to
               the URL.

  -debug       Activate verbose debugging messages

=cut

# notes:
# -request: an object implements the following methods:
#            ->url()            return the url for the request
#            ->method()         return the method for the request ('auto' allowed)
#            ->args()           return the args for the request
#            ->headers($hash)   do something with the HTTP headers (canonicalized)
#            ->start_body()     the body is starting, so do initialization
#            ->body($string)    a piece of the body text
#            ->finish_body()    the body has finished, so do cleanup
#            ->error()          set an error message
#
#  the request should return undef to abort the fetch and cause immediate cleanup
#
# -request: a Bio::Das::Request object
#
# -headers: hashref whose keys are HTTP headers and whose values are scalars or array refs
#           required headers will be added
#
sub new {
  my $pack = shift;
  my ($request,$headers,$proxy,$norfcwarn,$debug) = rearrange(['request',
							       'headers',
							       'proxy',
							       'norfcwarn',
							       'debug',
							      ],@_);
  croak "Please provide a -request argument" unless $request;

  # parse URL, return components
  my $dest = $proxy || $request->url;
  my ($mode,$host,$port,$path,$user,$pass) = $pack->parse_url($dest,$norfcwarn);
  croak "invalid url: $dest\n" unless $host;

  if (!$user && $request->auth) {
    ($user,$pass) = $request->auth;
  }

  # no headers to send by default
  $headers ||= {};

  # connect to remote host in nonblocking way
  my $sock = $pack->connect($mode,$host,$port);
  unless ($sock) {
    $request->error($pack->error);
    return;
  }

  $path = $request->url if $proxy;
  my $auth = ($user ? encode_base64("$user:$pass") : "");
  chomp($auth);

  # save the rest of our information
  return bless {
                # ("waiting", "reading header", "reading body", or "parsing body")
                status            => 'waiting',
                socket            => $sock,
                path              => $path,
		request           => $request,
		outgoing_headers  => $headers,
                host              => $host,
                # rather than encoding for every request
                auth              => $auth,
		mode              => $mode, #http vs https
		debug             => $debug,
		incoming_header   => undef,  # none yet
               },$pack;
}

# this will return the socket associated with the object

=item $socket = $fetcher->socket

Return the IO::Socket associated with the HTTP request.  The socket
is marked nonblocking and may not yet be in a connected state.

=item $path = $fetcher->path

Return the path part of the HTTP request.

=item $request = $fetcher->request

Return the L<Bio::Das::Request> object that the fetcher will attempt
to satisfy.

=item $args = $fetcher->args

Returns a hashref containing the CGI arguments to be passed to the
HTTP server.  This is simply delegated to the request's args() method.


=item $url = $fetcher->url

Returns the URL for the HTTP request. This is simply delegated to the
request's url() method.

=item $headers = $fetcher->outgoing_headers

Returns a hashref containing the HTTP headers that will be sent in the
request.

=item $host = $fetcher->host

Returns the host to which the fetcher will connect.  Note that this is
B<not> necessarily the same host as the DAS server, as this method
will return the name of the B<proxy> if an HTTP proxy has been
specified.  To get the DAS server hostname, call
$fetcher->request->host.

=item $credentials = $fetcher->auth

Return the authentication credentials as a base64-encoded string.

=item $header = $fetcher->incoming_header

Retrieve the incoming HTTP header.  Depending on the state of the
connection, the header may be empty or incomplete.

=cut

sub socket           { shift->{socket}           }
sub path             { shift->{path}             }
sub request          { shift->{request}          }
sub outgoing_args    { shift->request->args      }
sub url              { shift->request->url       }
sub outgoing_headers { shift->{outgoing_headers} }
sub host             { shift->{host}             }  # mostly for debugging purposes
sub auth             { shift->{auth}             }
sub incoming_header  { shift->{incoming_header}  }  # buffer for header data


=item $mode = $fetcher->mode([$new_mode])

This misnamed method gets or sets the protocol, which is one of 'http'
for regular cleartext transactions or 'https' for transactions using
the encrypting SSL/TLS protocol.  Note that you must have
IO::Socket::SSL and its associated libraries in order to use SSL/TLS.

=cut

sub mode {
  my $self = shift;
  my $d    = $self->{mode};
  $self->{mode} = shift if @_;
  $d;
}

=item $mode = $fetcher->mode([$new_mode])

This misnamed method gets or sets the protocol, which is one of 'http'
for regular cleartext transactions or 'https' for transactions using
the encrypting SSL/TLS protocol.  Note that you must have
IO::Socket::SSL and its associated libraries in order to use SSL/TLS.

=cut

sub method   {
  my $self = shift;
  my $meth = uc $self->request->method;
  return 'GET' unless $meth;
  if ($meth eq 'AUTO') {
    return $self->outgoing_args ? 'POST' : 'GET';
  }
  return $meth;
}

=item $status = $fetcher->status([$new_status])

This method is used to interrogate or change the status of the
transaction. The status keeps track of what has been done so far, and
is one of:

  waiting          # request not yet sent
  reading header   # request sent, waiting for HTTP header
  reading body     # HTTP header received, waiting for HTTP body
  parsing body     # HTTP body partially received, parsing it
  0                # transaction finished normally, EOF.

=cut

sub status   {
  my $self = shift;
  my $d    = $self->{status};
  $self->{status} = shift if @_;
  $d;
}

=item $debug = $fetcher->debug([$new_debug])

Get or set the debug flag, which enables verbose diagnostic messages.

=cut

sub debug {
  my $self = shift;
  my $d    = $self->{debug};
  $self->{debug} = shift if @_;
  $d;
}

=item ($protocol,$host,$port,$path,$user,$pass) = Bio::Das::HTTP::Fetch->parse_url($url,$norfcwarn)

This method is invoked as a class method (as
Bio::Das::HTTP::Fetch->parse_url) to parse a URL into its
components. The $norfcwarn flag inhibits a warning about the unsafe
nature of embedding username/password information in the URL of
unencrypted transactions.

=cut

# very basic URL-parsing sub
sub parse_url {
  my $self = shift;
  my ($url,$norfcwarn)  = @_;

  my ($ssl,$hostent,$path) = $url =~ m!^http(s?)://([^/]+)(/?[^\#]*)! or return;
  $path ||= '/';

  my ($user,$pass); 
  ($user, $hostent) = $hostent =~ /^(.*@)?(.*)/;
  ($user, $pass) = split(':',substr($user,0,length($user)-1)) if $user;
  if ($pass && !$ssl && !$norfcwarn) {
    warn "Using password in unencrypted URI against RFC #2396 recommendation";
  }

  my ($host,$port) = split(':',$hostent);
  my ($mode,$defport);
  if ($ssl) {
    $mode='https';
    $defport=443;
  } else {
    $mode='http';
    $defport=80;
  }
  return ($mode,$host,$port||$defport,$path,$user,$pass);
}

=item $socket = Bio::Das::HTTP::Fetch->connect($protocol,$host,$port)

This method is used to make a nonblocking connection to the indicated
host and port.  $protocol is one of 'http' or 'https'.  The resulting
IO::Socket will be returned in case of success.  Undef will be
returned in case of other errors.

=cut

# this is called to connect to remote host
sub connect {
  my $pack = shift;
  my ($mode,$host,$port) = @_;
  my $sock;
  if ($mode eq 'https') {
    load_ssl();
    $sock = IO::Socket::SSL->new(Proto => 'tcp',
				 Type => SOCK_STREAM,
				 SSL_use_cert => 0,
				 SSL_verify_mode => 0x00)
  } else {
    $sock = IO::Socket::INET->new(Proto => 'tcp',
				  Type  => SOCK_STREAM)
  }

  return unless $sock;
  $sock->blocking(0);
  my $host_ip = inet_aton($host) or return $pack->error("410 Unknown host $host");
  my $addr = sockaddr_in($port,$host_ip);
  my $result = $sock->IO::Socket::INET::connect($addr);  # don't allow SSL to do its handshake yet!
  return $sock if $result;  # return the socket if connected immediately
  return $sock if $! == EINPROGRESS;  # or if it's in progress
  return;                             # return undef on other errors
}

=item $status = $fetcher->send_request()

This method sends the HTTP request and returns the resulting status.
Because of the vagaries of nonblocking IO, the complete request can be
sent in one shot, in which case the returned status will be "reading
header", or only a partial request might have been written, in which
case the returned status will be "waiting."  In the latter case,
send_request() should be called again until the complete request has
been submitted.

If a communications error occurs, send_request() will return undef, in
which case it should not be called again.

=cut

# this is called to send the HTTP request
sub send_request {
  my $self = shift;
  warn "$self->send_request()" if $self->debug;

  die "not in right state, expected state 'waiting' but got '",$self->status,"'"
    unless $self->status eq 'waiting';

  unless ($self->{socket}->connected) {
    $! = $self->{socket}->sockopt(SO_ERROR);
    return $self->error("411 Couldn't connect: $!") ;
  }

  # if we're in https mode, then we need to complete the
  # SSL handshake at this point
  if ($self->mode eq 'https') {
    $self->complete_ssl_handshake($self->{socket}) || return $self->error("412 SSL error ".$self->{socket}->error);
  }

  $self->{formatted_request} ||= $self->format_request();

  warn "SENDING $self->{formatted_request}" if $self->debug;

  # Send the header and request.  Note that we have to respect
  # both IO::Socket EWOULDBLOCK errors as well as the dodgy
  # IO::Socket::SSL "SSL wants a write" error.
  my $bytes = syswrite($self->{socket},$self->{formatted_request});
  if (!$bytes) {
    return $self->status if $! == EWOULDBLOCK;  # still trying
    return $self->status if $self->{socket}->errstr =~ /SSL wants a write/;
    return $self->error("412 Communications error: $!");
  }
  if ($bytes >= length $self->{formatted_request}) {
    $self->status('reading header');
  } else {
    substr($self->{formatted_request},0,$bytes) = '';  # truncate and try again
  }
  $self->status;
}

=item $status = $fetcher->read()

This method is called when the fetcher is in one of the read states
(reading header, reading body or parsing body).  If successful, it
returns the new status.  If unsuccessful, it returns undef.

On the end of the transaction read() will return numeric 0.

=cut

# this is called when the socket is ready to be read
sub read {
  my $self = shift;
  my $stat = $self->status;
  return $self->read_header if $stat eq 'reading header';
  return $self->read_body   if $stat eq 'reading body'
                            or $stat eq 'parsing body';
}

# read the header through to the $CRLF$CRLF (blank line)
# return a true value for 200 OK
sub read_header {
  my $self = shift;

  my $bytes = sysread($self->{socket},$self->{header},READ_UNIT,length ($self->{header}||''));
  if (!defined $bytes) {
    return $self->status if $! == EWOULDBLOCK;
    return $self->status if $self->{socket}->errstr =~ /SSL wants a read/;
  }
  return $self->error("412 Communications error") unless $bytes > 0;

  # have we found the CRLF yet?
  my $i = rindex($self->{header},"$CRLF$CRLF");
  return $self->status unless $i >= 0;  # no, so keep waiting

  # found the header
  # If we have stuff after the header, then process it
  my $header     = substr($self->{header},0,$i);
  my $extra_data = substr($self->{header},$i+4);

  my ($status_line,@other_lines) = split $CRLF,$header;
  my ($stat_code,$stat_msg) = $status_line =~ m!^HTTP/1\.[01] (\d+) (.+)!;

  # If unauthorized, capture the realm for the authentication 
  if($stat_code == 401){
    # Can't use do_headers, Request will barf on lack of X-Das version
    if(my ($line) = grep /^WWW-Authenticate:\s+/, @other_lines){
      my ($scheme,$realm) = $line =~ /^\S+:\s+(\S+)\s+realm="(.*?)"/;  
      if($scheme ne 'Basic'){
        $self->error("413 Authentication scheme '$scheme' is not supported");
      }
      # The realm is actually allowed to be blank according to RFC #1945 BNF
      return $self->error("$stat_code '$realm' realm needs proper authentication");  
    }
  }

  # On non-200 status codes return an error
  return $self->error("$stat_code $stat_msg") unless $stat_code == 200;

  # handle header
  $self->do_headers(@other_lines) || return;

  $self->status('reading body');
  $self->do_body($extra_data) || return if length $extra_data;

  undef $self->{header};  # don't need header now
  return $self->status;
}

sub read_body {
  my $self = shift;
  my $data;
  my $result = sysread($self->{socket},$data,READ_UNIT);

  # call do_body() if we read data
  if ($result) {
    $self->do_body($data) or return;
    return $self->status;
  }

  # call request's finish_body() method on normal EOF
  elsif (defined $result) {
    $self->request->finish_body or return if $self->request;
    $self->status(0);
    return 0;
  }

  # sysread() returned undef, so error out
  else {
    return $self->status if $! == EWOULDBLOCK;  # well, this is OK
    return $self->status if $self->{socket}->errstr =~ /SSL wants a write/;
    my $errmsg = "read error: $!";
    if (my $cb = $self->request) {
      $cb->finish_body;
      $cb->error("412 Communications error: $errmsg");
    }
    return $self->error("412 Communications error: $errmsg");
  }

}

=item $http_request_string = $fetcher->format_request

This method generates the appropriate GET or POST HTTP request and the
HTTP request headers.

=cut

# this generates the appropriate GET or POST request
sub format_request {
  my $self    = shift;
  my $method  = $self->method;
  my $args    = $self->format_args;
  my $path    = $self->path;
  my $auth    = $self->auth;
  my $host    = $self->request->host;

  my @additional_headers = ('User-agent' => join('/',__PACKAGE__,$VERSION),
			    'Host'       => $host);
  push @additional_headers,('Authorization' => "Basic $auth") if $auth;
  push @additional_headers,('Content-length' => length $args,
			    'Content-type'   => 'application/x-www-form-urlencoded')
    if $args && $method eq 'POST';

  # probably don't want to do this
  $method = 'GET' if $method eq 'POST' && !$args;

  # there is an automatic CRLF pair at the bottom of headers, so don't add it
  my $headers = $self->format_headers(@additional_headers);

  return join CRLF,"$method $path HTTP/1.0",$headers,$args;
}

=item $cgi_query_string = $fetcher->format_args

This method generates the CGI query string.

=cut

# this creates the CGI request string
sub format_args {
  my $self = shift;
  my @args;
  if (my $a = $self->outgoing_args) {
    foreach (keys %$a) {
      next unless defined $a->{$_};
      my $key    = escape($_);
      my @values = ref($a->{$_}) eq 'ARRAY' ? map { escape($_) } @{$a->{$_}}
	                                    : $a->{$_};
      push @args,"$key=$_" foreach (grep {$_ ne ''} @values);
    }
  }

  #print STDERR "ARGS: ",join (';',@args) , "\n"; 
  return join ';',@args;
}


=item $headers = $fetcher->format_headers

This method generates the outgoing HTTP request headers, for use by
format_request().

=cut

# this creates the request headers
sub format_headers {
  my $self    = shift;
  my @additional_headers = @_;

  # this order allows overriding
  my %headers = (@additional_headers,%{$self->outgoing_headers});

  # clean up the headers
  my %clean_headers;
  for my $h (keys %headers) {  
    next if $h =~ /\s/;  # no whitespace allowed - invalid header
    my @values = ref($headers{$h}) eq 'ARRAY' ? @{$headers{$h}}
                                                : $headers{$h};
    foreach (@values) { s/[\n\r\t]/ / }        # replace newlines and tabs with spaces
    $clean_headers{canonicalize($h)} = \@values;  # canonicalize
  }

  my @lines;
  for my $k (keys %clean_headers) {
    for my $v (@{$clean_headers{$k}}) {
      push @lines,"$k: $v";
    }
  }

  return join CRLF,@lines,'';
}


=item $escaped_string = $fetcher->escape($unescaped_string)

This method performs URL escaping on the passed string.

=cut


sub escape {
  my $s = shift;
  $s =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
  $s;
}

=item $canonicalized_string = $fetcher->canonicalize($uncanonicalized_string)

This method canonicalizes the case of HTTP headers.

=cut

sub canonicalize {
  my $s = shift;
  $s = ucfirst lc $s;
  $s =~ s/(-\w)/uc $1/eg;
  $s;
}

=item $fetcher->do_headers(@header_lines)

This method parses the incoming HTTP header and saves the fields
internally where they can be accessed using the headers() method.

=cut

sub do_headers {
  my $self = shift;
  my @header_lines = @_;

  # split 'em into a hash, merge duplicates with semicolons
  my %headers;
  foreach (@header_lines) {
    my ($header,$value) = /^(\S+): (.+)$/ or next;
    $headers{canonicalize($header)} = $headers{$header} ? "; $value" : $value;
  }

  if (my $request = $self->request) {
    $request->headers(\%headers) || return $self->error($request->error);
  }
  1;
}

=item $result = $fetcher->do_body($body_data)

This method handles the parsing of the DAS document data by sending it
to the Bio::Das::Request object.  It returns a true result if parsing
was successful, or false otherwise.

=cut
# this is called to read the body of the message and act on it
sub do_body {
  my $self = shift;
  my $data = shift;

  my $request = $self->request or return;
  if ($self->status eq 'reading body') { # transition
    $request->start_body or return;
    $self->status('parsing body');
  }

  warn "parsing()...." if $self->debug;
  return $request->body($data);
}

=item $error = $fetcher->error([$new_error])

When called without arguments, error() returns the last error message
generated by the module.  When called with arguments, error() sets the
error message and returns undef.

=cut

# warn in case of error and return undef
sub error {
  my $self = shift;
  if (@_) {
    unless (ref $self) {
      $ERROR = "@_";
      return;
    }
    warn "$self->{url}: ",@_ if $self->debug;
    $self->{error} = "@_";
    return;
  } else {
    return ref($self) ? $self->{error} : $ERROR;
  }
}

=item $fetcher->load_ssl

This method performs initialization needed to use SSL/TLS transactions.

=cut

sub load_ssl {
  eval 'require IO::Socket::SSL' or croak "Must have IO::Socket::SSL installed to use https: urls: $@";

  # cheating a bit -- IO::Socket::SSL doesn't have this function, and needs to!
  eval <<'END' unless defined &IO::Socket::SSL::pending;
sub IO::Socket::SSL::pending {
  my $self = shift;
  my $ssl  = ${*$self}{'_SSL_object'};
  return Net::SSLeay::pending($ssl); # *
}
END

}

=item $fetcher->complete_ssl_handshake($sock)

This method is called to complete the SSL handshake, which must be
performed in blocking mode.  After completing the connection, the
socket is set back to nonblocking.

=cut

sub complete_ssl_handshake {
  my $self = shift;
  my $sock = shift;
  $sock->blocking(1);  # handshake requires nonblocking i/o
  my $result = $sock->connect_SSL($sock);
  $sock->blocking(0);
}

# necessary to define these methods so that IO::Socket::INET objects will act like
# IO::Socket::SSL objects.
sub IO::Socket::INET::pending { 0     }
sub IO::Socket::INET::errstr  { undef }


=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request>, L<Bio::Das::HTTP::Fetch>,
L<Bio::Das::Segment>, L<Bio::Das::Type>, L<Bio::Das::Stylesheet>,
L<Bio::Das::Source>, L<Bio::RangeI>

=cut

1;
