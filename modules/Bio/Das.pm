package Bio::Das;
# $Id$

# prototype parallel-fetching Das

use strict;
use Bio::Root::Root;
use Bio::Das::HTTP::Fetch;
use Bio::Das::TypeHandler;     # bring in the handler for feature type ontologies
use Bio::Das::Request::Dsn;    # bring in dsn  parser
use Bio::Das::Request::Types;  # bring in type parser
use Bio::Das::Request::Dnas;
use Bio::Das::Request::Features;
use Bio::Das::Request::Feature2Segments;
use Bio::Das::Request::Entry_points;
use Bio::Das::Request::Stylesheet;
use Bio::Das::FeatureIterator;
use Bio::Das::Util 'rearrange';
use Carp;

use IO::Socket;
use IO::Select;

use vars '$VERSION';
use vars '@ISA';
@ISA     = 'Bio::Root::Root';
$VERSION = 0.99;

*feature2segment = *fetch_feature_by_name = \&get_feature_by_name;
my @COLORS = qw(cyan blue red yellow green wheat turquoise orange);

sub new {
  my $package = shift;

  # compatibility with 0.18 API
  my ($timeout,$auth_callback,$url,$dsn,$oldstyle_api,$aggregators,$autotypes,$autocategories);
  my @p = @_;

  if (@p >= 1 && $p[0] =~ /^http/) {
    ($url,$dsn,$aggregators) = @p;
  } elsif ($p[0] =~ /^-/) {  # named arguments
    ($url,$dsn,$aggregators,$timeout,$auth_callback,$autotypes,$autocategories) 
      = rearrange([['source','server'],
		   'dsn',
		   ['aggregators','aggregator'],
		   'timeout',
		   'auth_callback',
		   'types',
		   'categories'
		  ],
		  @p);
  } else {
    ($timeout,$auth_callback) = @p;
  }

  $oldstyle_api = defined $url;

  my $self = bless {
		    'sockets'   => {},   # map socket to Bio::Das::HTTP::Fetch objects
		    'timeout'   => $timeout,
		    default_server => $url,
		    default_dsn    => $dsn,
		    oldstyle_api   => $oldstyle_api,
		    aggregators    => [],
		    autotypes      => $autotypes,
		    autocategories => $autocategories,
	       },$package;
  $self->auth_callback($auth_callback) if defined $auth_callback;
  if ($aggregators) {
    my @a = ref($aggregators) eq 'ARRAY' ? @$aggregators : $aggregators;
    $self->add_aggregator($_) foreach @a;
  }
  return $self;
}

sub name {
  my $url =   shift->default_url;
  # $url =~ tr/+-//d;
  $url;
}

# holds the last error when using the oldstyle api
sub error {
  my $self = shift;
  my $d    = $self->{error};
  $self->{error} = shift if @_;
  $d;
}

sub add_aggregator {
  my $self       = shift;
  my $aggregator = shift;
  warn "aggregator = $aggregator" if $self->debug;

  my $list = $self->{aggregators} ||= [];
  if (ref $aggregator) { # an object
    @$list = grep {$_->get_method ne $aggregator->get_method} @$list;
    push @$list,$aggregator;
  }

  elsif ($aggregator =~ /^(\w+)\{([^\/\}]+)\/?(.*)\}$/) {
    my($agg_name,$subparts,$mainpart) = ($1,$2,$3);
    my @subparts = split /,\s*/,$subparts;
    my @args = (-method    => $agg_name,
		-sub_parts => \@subparts);
    push @args,(-main_method => $mainpart) if $mainpart;
    warn "making an aggregator with (@args), subparts = @subparts" if $self->debug;
    require Bio::DB::GFF::Aggregator;
    push @$list,Bio::DB::GFF::Aggregator->new(@args);
  }

  else {
    my $class = "Bio::DB::GFF::Aggregator::\L${aggregator}\E";
    eval "require $class";
    $self->throw("Unable to load $aggregator aggregator: $@") if $@;
    push @$list,$class->new();
  }
}

sub aggregators {
  my $self = shift;
  my $d = $self->{aggregators};
  if (@_) {
    $self->clear_aggregators;
    $self->add_aggregator($_) foreach @_;
  }
  return unless $d;
  return @$d;
}

sub clear_aggregators { shift->{aggregators} = [] }

sub default_dsn {
  my $self = shift;
  my $d    = $self->{default_dsn};
  if (@_) {
    my $new_dsn = shift;
    $self->{default_dsn} = UNIVERSAL::isa($new_dsn,'Bio::Das::DSN') ?
                           $new_dsn->id : $new_dsn;
  }
  $d;
}

sub default_server { shift->{default_server} }

sub oldstyle_api   { shift->{oldstyle_api}   }

sub default_url {
  my $self = shift;
  return unless $self->default_server && $self->default_dsn;
  return join '/',$self->default_server,$self->default_dsn;
}

sub auth_callback{
  my $self = shift;
  if(defined $_[0]){
    croak "Authentication callback routine to set is not a reference to code" 
      unless ref $_[0] eq "CODE";
  }

  my $d    = $self->{auth_callback};
  $self->{auth_callback} = shift if @_;
  $d;
}

sub no_rfc_warning {
  my $self = shift;
  my $d   = $self->{no_rfc_warning};
  $self->{no_rfc_warning} = shift if @_;
  $d;
}

sub proxy {
  my $self = shift;
  my $d    = $self->{proxy};
  $self->{proxy} = shift if @_;
  $d;
}

sub timeout {
  my $self = shift;
  my $d = $self->{timeout};
  $self->{timeout} = shift if @_;
  $d;
}

sub debug {
  my $self = shift;
  my $d = $self->{debug};
  $self->{debug} = shift if @_;
  $d;
}

sub make_fetcher {
  my $self    = shift;
  my $request = shift;
  return Bio::Das::HTTP::Fetch->new(
				    -request   => $request,
				    -headers   => {'Accept-encoding' => 'gzip'},
				    -proxy     => $self->proxy || '',
				    -norfcwarn => $self->no_rfc_warning,
				   );
}

# call with list of base names
# will return a list of DSN objects

sub dsn_js5 {
  my $self = shift;
warn "DSN JS5: @_";
  my @requests = $_[0]=~/^-/ ? Bio::Das::Request::Dsn->new(@_) : map { Bio::Das::Request::Dsn->new($_) } @_;
warn ">>>";
  $self->run_requests(\@requests);
warn "<<<";
}


sub dsn {
  my $self = shift;
  return $self->default_dsn(@_) if $self->oldstyle_api;
  return $self->_dsn(@_);
}

sub _dsn {
  my $self = shift;
  my @dsns;
  if ($_[0] =~ /^-/) {
    my($dsn) = rearrange([['dsn','dsns']],@_);
    @dsns    = ref($dsn) eq 'ARRAY' ? @$dsn : ($dsn);
  }
  else {
    @dsns = @_;
  }
  my @requests = map { Bio::Das::Request::Dsn->new($_) } @dsns;
  warn "@dsns @requests";
  $self->run_requests(\@requests);
}

sub sources {
  my $self = shift;
  my $default_server = $self->default_server or return;
  return $self->_dsn($default_server);
}

sub entry_points {
  my $self = shift;
  my ($dsn,$ref,$callback) =  rearrange([['dsn','dsns'],
					 ['ref','refs','refseq','seq_id','name'],
					 'callback',
					],@_);
  $dsn ||= $self->default_url;
  croak "must provide -dsn argument" unless $dsn;
  my @dsn = ref $dsn ? @$dsn : $dsn;
  my @request;
  for my $dsn (@dsn) {
    push @request,Bio::Das::Request::Entry_points->new(-dsn    => $dsn,
						       -ref    => $ref,
						       -callback => $callback);
  }
  $self->run_requests(\@request);
}

sub stylesheet {
  my $self = shift;
  my ($dsn,$callback) =  rearrange([['dsn','dsns'],
				    'callback',
				   ],@_);
  $dsn ||= $self->default_url;
  croak "must provide -dsn argument" unless $dsn;
  my @dsn = ref $dsn ? @$dsn : $dsn;
  my @request;
  for my $dsn (@dsn) {
    push @request,Bio::Das::Request::Stylesheet->new(-dsn    => $dsn,
						     -callback => $callback);
  }
  $self->run_requests(\@request);
}


# call with list of DSN objects, and optionally list of segments and categories
sub types {
  my $self = shift;
  my ($dsn,$segments,$categories,$enumerate,$callback) = rearrange([['dsn','dsns'],
								    ['segment','segments'],
								    ['category','categories'],
								    'enumerate',
								    'callback',
								   ],@_);
  $dsn ||= $self->default_url;
  croak "must provide -dsn argument" unless $dsn;
  my @dsn = ref $dsn ? @$dsn : $dsn;
  my @request;
  for my $dsn (@dsn) {
    push @request,Bio::Das::Request::Types->new(-dsn        => $dsn,
						-segment    => $segments,
						-categories => $categories,
						-enumerate   =>$enumerate,
						-callback    => $callback,
					       );
  }
  $self->run_requests(\@request);
}

# call with list of DSN objects, and a list of one or more segments
sub dna {
  my $self = shift;
  my ($dsn,$segments,$callback) = rearrange([['dsn','dsns'],
					     ['segment','segments'],
					     'callback',
					    ],@_);
  $dsn ||= $self->default_url;
  croak "must provide -dsn argument" unless $dsn;
  my @dsn = ref $dsn && ref $dsn eq 'ARRAY' ? @$dsn : $dsn;
  my @request;
  for my $dsn (@dsn) {
    push @request,Bio::Das::Request::Dnas->new(-dsn        => $dsn,
					       -segment    => $segments,
					       -callback    => $callback);
  }
  $self->run_requests(\@request);
}

# 0.18 API - fetch by segment
sub segment {
  my $self = shift;
  my ($ref,$start,$stop,$version) = rearrange([['ref','name'],'start',['stop','end'],'version'],@_);
  my $dsn = $self->default_url;
  if (defined $start && defined $stop) {
    my $segment =  Bio::Das::Segment->new($ref,$start,$stop,$version,$self,$dsn);
    $segment->autotypes($self->{autotypes})           if $self->{autotypes};
    $segment->autocategories($self->{autocategories}) if $self->{autocategories};
    return $segment;
  } else {
    my @segments;
    my $request = Bio::Das::Request::Features->new(-dsn        => $dsn,
						   -das        => $self,
						   -segments   => $ref,
						   -type       => 'NULL',
						   -segment_callback => sub {
						     push @segments,shift;
						   });
    $self->run_requests([$request]);
    return if @segments == 0;
    return @segments    if wantarray;
    return $segments[0] if @segments == 1;
    $self->error('requested segment has more than one reference sequence in database.  Please call in a list context to retrieve them all.');
    $self->throw('multiple segment error');
  }
}

# 0.18 API - fetch by feature name - returns a set of Bio::Das::Segment objects
sub get_feature_by_name {
  my $self = shift;
  my ($class, $name, $dsn);
  if (@_ == 1) {
    $name = shift;
  } else {
    ($class, $name, $dsn)
      = $self->_rearrange([qw(CLASS NAME DSN)],@_);
  }
  $dsn ||= $self->default_url;
  croak "must provide -dsn argument" unless $dsn;
  my @dsn = ref $dsn && ref $dsn eq 'ARRAY' ? @$dsn : $dsn;
  my @requests = map { Bio::Das::Request::Feature2Segments->new(-class   => $class,
								-dsn     => $_,
								-feature => $name,
								-das     => $self,
							       )
  } @dsn;
  $self->run_requests(\@requests);
}

# gbrowse compatibility
sub refclass { 'Segment' }

# call with list of DSNs, and optionally list of segments and categories
sub features {
  my $self = shift;
  my ($dsn,$segments,$types,$categories,
      $fcallback,$scallback,$feature_id,$group_id,$iterator) 
                                 = rearrange([['dsn','dsns'],
			                      ['segment','segments'],
					      ['type','types'],
					      ['category','categories'],
					      ['callback','feature_callback'],
					      'segment_callback',
                                              'feature_id',
                                              'group_id',
					      'iterator',
					     ],@_);

  croak "must provide -dsn argument" unless $dsn;
  my @dsn = ref $dsn && ref $dsn eq 'ARRAY' ? @$dsn : $dsn;

  # handle types
  my @aggregators;
  my $typehandler = Bio::Das::TypeHandler->new;
  my $typearray   = $typehandler->parse_types($types);
  for my $a ($self->aggregators) {
    unshift @aggregators,$a if $a->disaggregate($typearray,$typehandler);
  }

  my @types = map {defined $_->[1] ? "$_->[0]:$_->[1]" : $_->[0]} @$typearray;
  my @request;
  for my $dsn (@dsn) {
    push @request,Bio::Das::Request::Features->new(
						   -dsn              => $dsn,
						   -segments         => $segments,
						   -types            => \@types,
						   -categories       => $categories,
						   -feature_callback => $fcallback  || undef,
						   -segment_callback => $scallback  || undef,
						   -das              => $self,
						   -feature_id       => $feature_id || undef,
						   -group_id         => $group_id   || undef,
                           );
  }
  my @results = $self->run_requests(\@request);
  $self->aggregate(\@aggregators,
		   $results[0]->can('results') ? \@results : [\@results],
		   $typehandler) if @aggregators && @results;
  return Bio::Das::FeatureIterator->new(\@results) if $iterator;
  return wantarray ? @results : $results[0];
}

sub search_notes { }

sub aggregate {
  my $self = shift;
  my ($aggregators,$featarray,$typehandler) = @_;
  my @f;

  foreach (@$featarray) {
    if (ref($_) eq 'ARRAY') { # 0.18 API
      push @f,$_;
    } elsif ($_->is_success) { # current API
      push @f,scalar $_->results;
    }
  }
  return unless @f;
  for my $f (@f) {
    for my $a (@$aggregators) {
      $a->aggregate($f,$typehandler);
    }
  }
}

sub add_pending {
  my $self    = shift;
  my $fetcher = shift;
  $self->{sockets}{$fetcher->socket} = $fetcher;
}

sub remove_pending {
  my $self    = shift;
  my $fetcher = shift;
  delete $self->{sockets}{$fetcher->socket};
}

sub run_requests {
  my $self     = shift;
  my $requests = shift;

warn ">>>rr1";
  for my $request (@$requests) {
    my $fetcher = $self->make_fetcher($request) or next;
    $fetcher->debug(1) if $self->debug;
    $self->add_pending($fetcher);
  }

  my $timeout = $self->timeout;

  # create two IO::Select objects to handle writing & reading
  my $readers = IO::Select->new;
  my $writers = IO::Select->new;

  for my $fetcher (values %{$self->{sockets}}) {
    my $socket = $fetcher->socket;
    $writers->add($socket);
  }

warn ">>>rr2";
  my $timed_out;
  while ($readers->count or $writers->count) {
warn ">>>a";
    my ($readable,$writable) = IO::Select->select($readers,$writers,undef,$timeout);

    ++$timed_out && last unless $readable || $writable;

    foreach (@$writable) {                      # handle is ready for writing
      my $fetcher = $self->{sockets}{$_};       # recover the HTTP fetcher
      my $result = $fetcher->send_request();               # try to send the request
      if ($result) {
	if ($result eq 'reading header') {    # request is sent, so monitor for reading
	  $readers->add($_);
	  $writers->remove($_);               # and remove from list monitored for writing
	}
      } else {  # some sort of error
	$fetcher->request->error($fetcher->error());       # copy the error message
	$writers->remove($_);                              # and remove from list monitored for writing
      }
    }
warn ">>>b";
    foreach (@$readable) {                      # handle is ready for reading
warn ">>>sock";
      my $fetcher = $self->{sockets}{$_};       # recover the HTTP object
warn ">>>fetch";
warn ref($fetcher);
warn $fetcher->can('can_read') ? $fetcher->can_read( 1 ) : '';
warn $fetcher->can('read') ? 'YYYY' : 'XXXX';
      my $result = $fetcher->read;              # read some data
warn ">>>d";
      if($fetcher->error
	     && $fetcher->error =~ /^401\s/
	     && $self->auth_callback()) {       # Don't give up if given authentication challenge
	# The result will automatically appear, as fetcher contains request reference
	my $new_sock = $self->authenticate($fetcher);
	if ($new_sock) {
	  $writers->remove($_);
	  $readers->remove($_);
	  $writers->add($new_sock);
	}
      }
warn ">>>e";
      unless ($result) {                        # remove if some error occurred
	$fetcher->request->error($fetcher->error) unless defined $result;
	$readers->remove($_);
	delete $self->{sockets}{$_};
      }
warn ">>>f";
    }
warn ">>>c";
  }

warn ">>>rr3";
  # handle timeouts
  if ($timed_out) {
    while (my ($sock,$f) = each %{$self->{sockets}}) { # list of still-pending requests
      $f->request->error('509 timeout');
      $readers->remove($sock);
      $writers->remove($sock);
      close $sock;
    }
  }

warn ">>>rr4";
  delete $self->{sockets};
  if ($self->oldstyle_api()) {
    unless ($requests->[0]->is_success) {
      $self->error($requests->[0]->error);
      return;
    }
    return wantarray ? $requests->[0]->results : ($requests->[0]->results)[0];
  }
warn ">>>rr5";
  return wantarray ? @$requests : $requests->[0];
}

# The callback routine used below for authentication must accept three arguments: 
#    the fetcher object, the realm for authentication, and the iteration
# we are on.  A return of undef means that we should stop trying this connection (e.g. cancel button
# pressed, or x number of iterations tried), otherwise a two element array (not a reference to an array)
# should be returned with the username and password in that order.
# I assume if you've called autheniticate, it's because you've gotten a 401 error. 
# Otherwise this does not make sense.
# There is also no caching of authentication done.  I suggest the callback do this, so
# the user isn't asked 20 times for the same name and password.

sub authenticate($$$){
  my ($self, $fetcher) = @_;
  my $callback = $self->auth_callback;

  return undef unless defined $callback;

  $self->{auth_iter} = {} if not defined $self->{auth_iter};

  my ($realm) = $fetcher->error =~ /^\S+\s+'(.*)'/; 

  return if $self->{auth_iter}->{$realm} < 0;  # Sign that we've given up, don't try again

  my ($user, $pass) = &$callback ($fetcher, $realm, ++($self->{auth_iter}->{$realm}));

  if(!defined $user or $user eq ''){  #Give up, denote with negative iteration value
    $self->{auth_iter}->{$realm} = -1;
    return;
  }

  # Reuse request, adding the authentication info
  my $request = $fetcher->request;
  $self->remove_pending($fetcher);

  # How do we clean up the old fetcher,which is no longer needed?
  $request->auth($user,$pass);
  my $new_fetcher =  $self->make_fetcher($request) or return;
  $self->add_pending($new_fetcher);
  return $new_fetcher->socket;
}

1;

__END__


=head1 NAME

Bio::Das - Interface to Distributed Annotation System

=head1 SYNOPSIS

  use Bio::Das;

   # SERIAL API
   my $das = Bio::Das->new(-source => 'http://www.wormbase.org/db/das',
                           -dsn    => 'elegans',
                           -aggregators => ['primary_transcript','clone']);
   my $segment  = $das->segment('Chr1');
   my @features = $segment->features;
   my $dna      = $segment->dna;

  # PARALLEL API
  # create a new DAS agent with a timeout of 5 sec
  my $das = Bio::Das->new(5);

  # fetch features from wormbase live and development servers spanning two segments on chromosome I
  my @request = $das->features(-dsn     => ['http://www.wormbase.org/db/das/elegans',
  					    'http://dev.wormbase.org/db/das/elegans',
					   ],
			       -segment => ['I:1,10000',
					    'I:10000,20000'
					   ]
			      );

  for my $request (@request) {
    if ($request->is_success) {
      print "\nResponse from ",$request->dsn,"\n";
      my $results = $request->results;
      for my $segment (keys %$results) {
	my @features = @{$results->{$segment}};
	print "\t",join ' ',$segment,@features,"\n";
      }
    }

    else { #error
      warn $request->dsn,": ",$request->error,"\n";
    }
  }

  # Same thing, but using a callback:
  $das->features(-dsn     => ['http://www.wormbase.org/db/das/elegans',
			      'http://dev.wormbase.org/db/das/elegans',
			      ],
	  	 -segment => ['I:1,10000',
                              'I:10000,20000'
                             ],
		 -callback => sub { my $feature = shift;
                                    my $segment = $feature->segment;
                                    my ($start,$end) = ($feature->start,$feature->end);
                                    print "$segment => $feature ($start,$end)\n";
                                  }
			       );


=head1 DESCRIPTION

Bio::Das provides access to genome sequencing and annotation databases
that export their data in Distributed Annotation System (DAS) format
version 1.5.  This system is described at http://biodas.org.  Both
unencrypted (http:) and SSL-encrypted (https:) DAS servers are
supported.  (To run SSL, you will need IO::Socket::SSL and Net::SSLeay
installed).

The components of the Bio::Das class hierarchy are:

=over 4

=item Bio::Das

This class performs I/O with the DAS server, and is responsible for
generating DAS requests.  At any time, multiple requests to different
DAS servers can be running simultaneously.

=item Bio::Das::Request

This class encapsulates a request to a particular DAS server.  After
execution of the request, the response can be recovered from the
object as well.  Methods allow you to return the status of the
request, the error message if any, and the data results.

=item Bio::Das::Segment

This encapsulates information about a segment on the genome, and
contains information on its start, end and length.

=item Bio::Das::Feature

This provides information on a particular feature of a
Bio::Das::Segment, such as its type, orientation and score.

=item Bio::Das::Type

This class contains information about a feature's type, and is a
holder for an ontology term.

=item Bio::Das::DSN

This class contains information about a DAS data source.

=item Bio::Das::Stylesheet

This class contains information about the stylesheet for a DAS source.

=back

=head2 PARALLEL AND SERIAL APIs

Bio::Das supports two distinct APIs. One is a parallel API which
allows you to make Das requests on two or more servers simultaneously.
This is highly efficient, but the API is slightly more difficult to
use.  The other is a serial API which supports only a single request
on a single service.  It is recommended for simple scripts or for
those where performance is not at a premium.

The two APIs use the same objects. You select which API to use when
you create the Das object with Bio::Das->new().

=head2 OBJECT CREATION

The public Bio::Das constructor is new().  It is used both for the
parallel and serial APIs.

B<Serial API object construction:>

=over 4

=item $das = Bio::Das->new(-server => $url, -dsn => $dsn, -aggregators=>\@aggregators);

Clients that will be accessing a single server exclusively can
indicate that they wish to use the serial APi by passing the
B<-server> argument.  The argument for B<-server> is the base name of
the DAS server (e.g. http://www.wormbase.org/db/das).  You may also
select the data source to use (e.g. "elegans") by passing the B<-dsn>
argument. B<-aggregators> is a list of aggregators as described
earlier.

=item $das = Bio::Das->new('http://das.server/cgi-bin/das',$dsn,$aggregators)

Shortcut for the above.

=back

B<Parallel API object construction:>

=over 4

=item $das = Bio::Das->new(-timeout       => $timeout,
                           -auth_callback => $authentication_callback,
                           -aggregators   => \@aggregators)

Create a new Bio::Das object, with the indicated timeout and optional
callback for authentication.  The timeout will be used to decide when
a server is not responding and to return a "can't connect" error.  Its
value is in seconds, and can be fractional (most systems will provide
millisecond resolution).  The authentication callback will be invoked
if the remote server challenges Bio::Das for authentication credentials.

Aggregators are used to build multilevel hierarchies out of the raw
features in the DAS stream.  For a description of aggregators, see
L<Bio::DB::GFF>, which uses exactly the same aggregator system as
Bio::Das.

If successful, this method returns a Bio::Das object.

=item $das = Bio::Das->new($timeout [,$authentication_callback])

Shortcut for the above.

=back

=head2 ACCESSOR METHODS

Once created, the Bio::Das object provides the following accessor methods:

=over 4

=item $proxy = $das->proxy([$new_proxy])

Get or set the proxy to use for accessing indicated servers.  Only
HTTP and HTTPS proxies are supported at the current time.

=item $callback = $das->auth_callback([$new_callback])

Get or set the callback to use when authentication is required.  See
the section "Authentication" for more details.

=item $timeout = $das->timeout([$new_timeout])

Get or set the timeout for slow servers.

=item $error  = $das->error

Get a string that describes the last error the module encountered whie
using the serial API.  If you are using the parallel API, then use the
request object's error() method to retrieve the error message from the
corresponding request.

=item $debug  = $das->debug([$debug_flag])

Get or set a flag that will turn on verbose debugging messages.

=item $das->add_aggregator($aggregator)

Aggregators allow you to dynamically build up more multipart features
from the simple one-part that are returned by Das servers.  The
concept of aggregation was introduced in the L<Bio::DB::GFF> module,
and is completely compatible with the Bio::Das implementation.  See
L<Bio::DB::GFF> and L<Bio::DB::GFF::Aggregator> for information on how
to create and use aggregators.

The add_aggregator() method will append an aggregator to the end of
the list of registered aggregators.  Three different argument types
are accepted:

  1) a Bio::DB::GFF::Aggregator object -- will be added
  2) a string in the form "aggregator_name{subpart1,subpart2,subpart3/main_method}"
         -- will be turned into a Bio::DB::GFF::Aggregator object (the /main_method
        part is optional).
  3) a valid Perl token -- will be turned into a Bio::DB::GFF::Aggregator
        subclass, where the token corresponds to the subclass name.

=item $das->aggregators([@new_aggregators]);

This method will get or set the list of aggregators assigned to
the database.  If 1 or more arguments are passed, the existing
set will be cleared.

=item $das->clear_aggregators

This method will clear the aggregators stored in the database object.
Use aggregators() or add_aggregator() to add some back.

=back

=head2 DATA FETCHING METHODS - SERIAL API

We will document that serial API first, followed by the parallel API.
Do not be confused by the fact is that both serial and parallel APIs
have the same method names.  The behavior of the methods are
determined solely by whether the B<-server> argument was provided to
Bio::Das->new() during object construction.

=over 4

=item @dsn = $das->sources

Return a list of data sources available from this server.  This is one
of the few methods that can be called before setting the data source.

=item $segment = $das->segment($id)

=item $segment = $das->segment(-ref => $reference [,@args]);

The segment() method returns a new Bio::Das::Segment object, which can
be queried for information related to a sequence segment.  There are
two forms of this call.  In the single-argument form, you pass
segment() an ID to be used as the reference sequence.  Sequence IDs
are server-specific (some servers will accept genbank accession
numbers, others more complex IDs such as Locus:unc-9).  The method
will return a Bio::Das::Segment object containing a region of the
genomic corresponding to the ID.

Once you fetch the segment, you can use it to fetch the features that
overlap that segment, or the DNA corresponding to the segment.  For
example:

   my @features = $segment->features();
   my $dna      = $segment->dna();

See L<Bio::Das::Segment> for more details.

Instead of a segment ID, you may use a previously-created
Bio::Das::Segment object, in which case a copy of the segment will be
returned to you.  You can then adjust its start and end positions.

In the multiple-argument form, you pass a series of argument/value
pairs:

  Argument   Value                   Default
  --------   -----                   -------

  -ref       Reference ID            none
  -segment   Bio::Das::Segment obj   none
  -start     Starting position       1
  -end       Ending position         length of ref ID
  -offset    Starting position       0
             (0-based)
  -length    Length of segment       length of ref ID

The B<-ref> argument is required, and indicates the ID of the genomic
segment to retrieve.  B<-segment> is optional, and can be used to use
a previously-created Bio::Das::Segment object as the reference point
instead.  If both arguments are passed, B<-segment> supersedes
B<-ref>.

B<-start> and B<-end> indicate the start and stop of the desired
genomic segment, relative to the reference ID.  If not provided, they
default to the start and stop of the reference segment.  These
arguments use 1-based indexing, so a B<-start> of 0 positions the
segment one base before the start of the reference.

B<-offset> and B<-length> arguments are alternative ways to indicate a
segment using zero-based indexing.  It is probably not a good to mix
the two calling styles, but if you do, be aware that B<-offset>
supersedes B<-start> and B<-length> supersedes B<-stop>.

Note that no checking of the validity of the passed reference ID will
be performed until you call the segment's features() or dna() methods.

=item @segments = $das->get_feature_by_name(-name=>$name [,-class=>$class]);

This method implements the DAS feature request using parameters that
will translate a feature name into one or more segments.  This can be
used to retrieve the section of a genome that is occupied by a
particular feature.  If the feature name matches multiple features in
discontinuous parts of the genome, this call may return multiple
segments.  Once you have a segment, you can call its features() method
to get information about the features that overlap this region.

The optional -class argument is provided to deal with servers that
have namespaced their features using a colon.
$das->get_feature_by_name(-name=>'foo',-class=>'bar') is exactly
equivalent to $das->get_feature_by_name(-name=>'bar:foo').

Because this method is misnamed (it returns segments, not features),
it is also known as feature2segment().

The method can also be called using the shortcut syntax
get_feature_by_name($name).

=item @entry_points = $das->entry_points

The entry_points() method returns an array of Bio::Das::Segment
objects that have been designated "entry points" by the DAS server.
Also see the Bio::Das::Segment->entry_points() method.

=item $stylesheet = $das->stylesheet

Return the stylesheet from the remote DAS server.  The stylesheet
contains suggestions for the visual format for the various features
provided by the server and can be used to translate features into
glyphs.  The object returned is a Bio::Das::Stylesheet object.

=item @types = $das->types

This method returns a list of all the annotation feature types served
by the DAS server.  The return value is an array of Bio::Das::Type
objects.

=back

=head2 DATA FETCHING METHODS - PARALLEL API

The following methods accept a series of arguments, contact the
indicated DAS servers, and return a series of request objects from
which you can learn the status of the request and fetch the results.

Parallel API:

=over 4

=item @request = $das->dsn(@list_of_urls)

The dsn() method accepts a list of DAS server URLs and returns a list
of request objects containing the DSNs provided by each server.

The request objects will indicate whether each request was successful
via their is_success() methods.  For your convenience, the request
object is automagically stringified into the requested URL.  For
example:

 my $das = Bio::Das->new(5);  # timeout of 5 sec
 my @response = $das->dsn('http://stein.cshl.org/perl/das',
  			 'http://genome.cse.ucsc.edu/cgi-bin/das',
			 'http://user:pass@www.wormbase.org/db/das',
			 'https://euclid.well.ox.ac.uk/cgi-bin/das',
			);

 for my $url (@response) {
   if ($url->is_success) {
     my @dsns = $url->results;
     print "$url:\t\n";
     foreach (@dsns) {
       print "\t",$_->url,"\t",$_->description,"\n";
     }
   } else {
     print "$url: ",$url->error,"\n";
   }
 }

Each element in @dsns is a L<Bio::Das::DSN> object that can be used
subsequently in calls to features(), types(), etc.  For example, when
this manual page was written, the following was the output of this
script.

 http://stein.cshl.org/perl/das/dsn:	
 http://stein.cshl.org/perl/das/chr22_transcripts	This is the EST-predicted transcripts on...

 http://servlet.sanger.ac.uk:8080/das:	
 http://servlet.sanger.ac.uk:8080/das/ensembl1131   The latest Ensembl database	

 http://genome.cse.ucsc.edu/cgi-bin/das/dsn:	
 http://genome.cse.ucsc.edu/cgi-bin/das/hg8	Human Aug. 2001 Human Genome at UCSC
 http://genome.cse.ucsc.edu/cgi-bin/das/hg10	Human Dec. 2001 Human Genome at UCSC
 http://genome.cse.ucsc.edu/cgi-bin/das/mm1	Mouse Nov. 2001 Human Genome at UCSC
 http://genome.cse.ucsc.edu/cgi-bin/das/mm2	Mouse Feb. 2002 Human Genome at UCSC
 http://genome.cse.ucsc.edu/cgi-bin/das/hg11	Human April 2002 Human Genome at UCSC
 http://genome.cse.ucsc.edu/cgi-bin/das/hg12	Human June 2002 Human Genome at UCSC
 http://user:pass@www.wormbase.org/db/das/dsn:	
 http://user:pass@www.wormbase.org/db/das/elegans     This is the The C. elegans genome at CSHL
 
 https://euclid.well.ox.ac.uk/cgi-bin/das/dsn:	
 https://euclid.well.ox.ac.uk/cgi-bin/das/dicty	        Test annotations
 https://euclid.well.ox.ac.uk/cgi-bin/das/elegans	C. elegans annotations on chromosome I & II
 https://euclid.well.ox.ac.uk/cgi-bin/das/ensembl	ensembl test annotations
 https://euclid.well.ox.ac.uk/cgi-bin/das/test	        Test annotations
 https://euclid.well.ox.ac.uk/cgi-bin/das/transcripts	transcripts test annotations

Notice that the DSN URLs always have the format:

 http://www.wormbase.org/db/das/$DSN
 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In which the ^^^ indicated part is identical to the server address.

=item @request = $das->types(-dsn=>[$dsn1,$dsn2],@other_args)

The types() method asks the indicated servers to return the feature
types that they provide.  Arguments are name-value pairs:

  Argument      Description
  --------      -----------

  -dsn          A DAS DSN, as returned by the dsn() call.  You may
                also provide a simple string containing the DSN URL.
                To make the types() request on multiple servers, pass an
                array reference containing the list of DSNs.

  -segment      (optional) An array ref of segment objects.  If provided, the
                list of types will be restricted to the indicated segments.

  -category     (optional) An array ref of type categories.  If provided,
                the list of types will be restricted to the indicated
                categories.

  -enumerate    (optional) If true, the server will return the count of
                each type.  The count can be retrieved using the 
                L<Bio::Das::Type> objects' count() method.

  -callback     (optional) Specifies a subroutine to be invoked on each
                type object received.

Segments have the format: "seq_id:start,end".  If successful, the
request results() method will return a list of L<Bio::Das::Type>
objects.

If a callback is specified, the code ref will be invoked with two
arguments.  The first argument is the Bio::Das::Segment object, and
the second is an array ref containing the list of types present in
that segment.  If no -segment argument was provided, then the callback
will be invoked once with a dummy segment (a version, but no seq_id,
start or end), and an arrayref containing the types.  If a callback is
specified, then the @request array will return the status codes for
each request, but invoking results() will return empty.

=item @request = $das->entry_points(-dsn=>[$dsn1,$dsn2],@other_args)

Invoke an entry_points request.  Arguments are name-value pairs:

  Argument      Description
  --------      -----------

  -dsn          A DAS DSN, as returned by the dsn() call.  You may
                also provide a simple string containing the DSN URL.
                To make the types() request on multiple servers, pass an
                array reference containing the list of DSNs.

  -callback     (optional) Specifies a subroutine to be invoked on each
                segment object received.

If a callback is specified, then the @request array will contain the
status codes for each request, but the results() method will return
empty.

Successful requests will return a set of Bio::Das::Segment objects.

=item @request = $das->features(-dsn=>[$dsn1,$dsn2],@other_args)

Invoke a features request to return a set of Bio::Das::Feature
objects.  The B<-dsn> argument is required, and may point to a single
DSN or to an array ref of several DSNs.  Other arguments are optional:

  Argument      Description
  --------      -----------

  -dsn          A DAS DSN, as returned by the dsn() call.  You may
                also provide a simple string containing the DSN URL.
                To make the types() request on multiple servers, pass an
                array reference containing the list of DSNs.

  -segment      A single segment, or an array ref containing
                several segments.  Segments are either Bio::Das::Segment
                objects, or strings of the form "seq_id:start,end".

  -type         (optional) A single feature type, or an array ref containing
                several feature types.  Types are either Bio::Das::Type
                objects, or plain strings.

  -category     (optional) A single feature type category, or an array ref
                containing several categories.  Category names are described
                in the DAS specification.

  -feature_id   (optional) One or more feature IDs.  The server will return
                the list of segment(s) that contain these IDs.  You will
                need to check with the data provider for the proper format
                of the IDs, but the style "class:ID" is common.  This will
                be replaced in the near future by LSID-style IDs.  Also note
                that only servers compliant with the 1.52 version of the
                spec will honor this.

  -group_id     (optional) One or more group IDs.  The server will return
                the list of segment(s) that contain these IDs.  You will
                need to check with the data provider for the proper format
                of the IDs, but the style "class:ID" is common.  This will
                be replaced in the near future by LSID-style IDs.  Also note
                that only servers compliant with the 1.52 version of the
                spec will honor this.

  -callback     (optional) Specifies a subroutine to be invoked on each
                Bio::Das::Feature object received.

  -segment_callback (optional) Specifies a subroutine to be invoked on each
                    Segment that is retrieved.

  -iterator     (optional)  If true, specifies that an iterator should be
                returned rather than a list of features.

The features() method returns a list of L<Bio::Das::Request> objects.
There will be one request for each DAS DSN provided in the B<-dsn>
argument.  Requests are returned in the same order that they were
passed to B<-dsn>, but you can also query the Bio::Das::Request
object to determine which server processed the request.  See Fetching
Results for details.  If you happen to call this method in a scalar
context, it will return the first request, discarding the rest.

If a callback (-callback or -segment_callback) is specified, then the
@request array will contain the status codes for each request, but
results() will return empty.

The subroutine specified by -callback will be invoked every time a
feature is encountered.  The code will be passed a single argument
consisting of a Bio::Das::Feature object.  You can find out what
segment this feature is contained within by executing the object's
segment() method.

The subroutine specified by -segment_callback will be invoked every
time one of the requested segments is finished.  It will be invoked
with two arguments consisting of the name of the segment and an array
ref containing the list of Bio::Das::Feature objects contained within
the segment.

If both -callback and -segment_callback are specified, then the first
subroutine will be invoked for each feature, and the second will be
invoked on each segment *AFTER* the segment is finished.  In this
case, the segment processing subroutine will be passed an empty list
of features.

Note, if the -segment argument is not provided, some servers will
provide all the features in the database.

The -iterator argument is a true/false flag.  If true, the call will
return a L<Bio::Das::FeatureIterator> object.  This object implements
a single method, next_seq(), which returns the next Feature.  Example:

   $iterator = $das->features(-dsn=>[$dsn1,$dsn2],-iterator=>1);
   while (my $feature = $iterator->next_seq) {
     my $dsn  = $feature->segment->dsn;
     my $type = $feature->type;
     print "got a $type from $dsn\n";
   }

=item @request = $das->dna(-dsn=>[$dsn1,$dsn2],@other_args)

Invoke a features request to return a DNA string.  The -dsn argument
is required, and may point to a single DSN or to an array ref of
several DSNs.  Other arguments are optional:

  Argument      Description
  --------      -----------

  -dsn          A DAS DSN, as returned by the dsn() call.  You may
                also provide a simple string containing the DSN URL.
                To make the types() request on multiple servers, pass an
                array reference containing the list of DSNs.

  -segment      (optional) A single segment, or an array ref containing
                several segments.  Segments are either Bio::Das::Segment
                objects, or strings of the form "seq_id:start,end".

  -callback     (optional) Specifies a subroutine to be invoked on each
                DNA string received.

-dsn, -segment and -callback have the same meaning that they do in
similar methods.

=item @request = $das->stylesheet(-dsn=>[$dsn1,$dsn2],@other_args)

Invoke a stylesheet request to return the L<Bio::Das::Stylesheet>
object.  The -dsn argument is required, and may point to a single DSN
or to an array ref of several DSNs.  Other arguments are optional:

  Argument      Description
  --------      -----------

  -dsn          A DAS DSN, as returned by the dsn() call.  You may
                also provide a simple string containing the DSN URL.
                To make the types() request on multiple servers, pass an
                array reference containing the list of DSNs.

  -segment      (optional) A single segment, or an array ref containing
                several segments.  Segments are either Bio::Das::Segment
                objects, or strings of the form "seq_id:start,end".

  -callback     (optional) Specifies a subroutine to be invoked on each
               stylesheet received.

-dsn, -segment and -callback have the same meaning that they do in
similar methods.

=item @request = $das->get_feature_by_name(-dsn=>[$dsns],-name=>$name [,-class=>$class]);

This method implements the DAS feature request using parameters that
will translate a feature name into one or more segments.  This can be
used to retrieve the section of a genome that is occupied by a
particular feature.  If the feature name matches multiple features in
discontinuous parts of the genome, this call may return multiple
segments.  Once you have a segment, you can call its features() method
to get information about the features that overlap this region.

The optional -class argument is provided to deal with servers that
have namespaced their features using a colon.
$das->get_feature_by_name(-name=>'foo',-class=>'bar') is exactly
equivalent to $das->get_feature_by_name(-name=>'bar:foo').

Because this method is misnamed (it returns segments, not features),
it is also known as feature2segment().

In case of a successful request, the request results() method will
return a list of Bio::Das::Segment objects, which can then be passed
back to features().

=back

=head2 Fetching Results

When using the parallel API, the dsn(), features(), dna(), and
stylesheet() methods will return an array of L<Bio::Das::Request>
objects.  Each object contains information about the outcome of the
request and the results, if any, returned.  The request objects
correspond to each of the DSNs passed to the request in the B<-dsn>
argument, and have the same number and order.

Because of the inherent uncertainties of the Internet, any DAS request
can fail.  It could fail because of a network transmission error, a
timeout, a down server, an HTTP URL-not-found error, or an unparseable
DAS document.  For this reason, you should check each request's
is_success() method before trying to use the results.  Here is the
canonical code:

  my @requests = $das->some_method(-dsn=>[$dsn1,$dsn2,$dsn3]);
  for my $request (@requests) {
    if ($request->is_success) {
       my $results = $request->results;
       # do something with the results
    }

    else {
       warn $request->error;
    }
  }

The is_success() method returns true on a successful request, false
otherwise.  In case of an unsuccessful request, the error() method
will provide additional information on why the request failed The
format is "XXXX human-readable string" as in:

    400 Bad command

The following error strings can be returned:

       400 Bad command
       401 Bad data source
       402 Bad command arguments
       403 Bad reference object
       404 Bad stylesheet
       405 Coordinate error
       410 Unknown host
       411 Couldn't connect
       412 Communications error
       413 Authentication scheme 'xxxx" is not supported
       500 Server error
       501 Unimplemented feature
       502 No X-Das-Version header
       503 Invalid X-Das-Version header
       504 DAS server is too old
       505 No X-Das-Status header
       506 Data decompression failure

To discover which server a request was sent to, you can call its dsn()
method.  This will return the server and data source as a single URL,
e.g.:

   my $dsn = $request->dsn;
   print $dsn,"\n";  # prints 'http://www.wormbase.org/db/das/elegans'

What is returned is actually a L<Bio::Das::DSN> object.  You can call
the object's base() method to return the server part of the DSN, and
its id() method to return the data source:

   my $dsn = $request->dsn;
   print $dsn->base,"\n";  # prints 'http://www.wormbase.org/db/das'
   print $dsn->id,"\n";    # prints 'elegans'

To get the results of from the request, call its results() method.  In
a list context, results() will return a list of the appropriate
objects for the request (a set of L<Bio::Das::Feature> objects for the
features() request a set of L<Bio::Das::Stylesheet> objects for the
stylesheet() request, a set of L<Bio::Das::Type> objects for the
types() request, and a set of raw DNA strings for the dna()
request.)

In a scalar context, results() will return a hashref in which the keys
are the segment strings passed to the request with the B<-segments>
argument and the values are arrayrefs containing the list of results.

There is an equivalence here.  When this code fragment executes, both
$results_hash1 and $results_hash2 will contain the same information.

  my @results = $request->results;
  my $result_hash1 = {};
  for my $r (@results) {
     my $segment = $r->segment;
     push @{$result_hash{$segment}},$r;
  }

  my $result2_hash2 = $request->results;

=head2 Authentication

It may be desirable to access DAS data that is stored in an
authenticating (password protected) server.  Only HTTP Basic
authentication is currently supported by Bio::Das, but you can run the
authentication over an SSL connection, thereby avoiding the risk of
passwords being sniffed.

Authentication information can be passed to the server in either of
two ways:

=over 4

=item In the server's URL

You can provide the username and password in the form:

   http://user:pass@my.das.server.org/cgi-bin/das

Where B<user> and B<pass> are the username and password required for
authentication.

Unless you do with this an SSL (https:) connection, you will get a
warning that using the password in the URL violates the recommendation
in RFC 2396.  You can suppress this warning using the no_rfc_warning()
method:

  $das->no_rfc_warning(1);

=item Using an authentication callback

You can provide a subroutine code reference that returns the username
and password at the time you create the Bio::Das object.  When
accessing a password protected site, Bio::Das will invoke your
callback using information about the request. The callback will return
the appropriate username and password.  You can do whatever you need
to do to get the authentication information, whether accessing an
enterprise database, or popping up a dialog box for the user to
respond to.

=back

To install an authentication callback, pass a coderef to
the B<-auth_callback> argument when calling Bio::Das->new():

  Bio::Das->new(-auth_callback=>\&my_authentication_routine);

The callback will be called with three arguments:

  my_authentication_routine($fetcher,$realm,$iteration_count)

B<$fetcher> is an L<Bio::Das::HTTP::Fetch> object.  It contains the
information you will need to determine which server is requesting
authentication.  You will probably want to call the fetch object's
host() method to get the name of the DAS host, but if you require more
information, the request() method will return the L<Bio::Das::Request>
object with complete information about the request.

B<$realm> is the Basic Authentication Realm string, as returned by the
remote server.

B<$iteration_count> records the number of times your authentication
routine has been invoked for this particular realm.  You can use this
information to abort authentication if it fails the first time.

The authentication callback should a two-element list containing the
username and password for authentication against the server.  If it
returns an empty list, the request will be aborted.

Here is a sample authentication routine.  It prompts the user up to
three times for his username and password, and then aborts.  Notice
the way in which the hostname is recovered from the
Bio::Das::HTTP::Fetch object.

 sub my_authentication_routine {
   my ($fetcher,$domain,$iteration_count) = @_;
   return if $iteration_count > 3;
   my $host = $fetcher->request->host;
   print STDERR "$host/$domain requires authentication (try $iteration_count of 3)\n";
   print STDERR "Username: ";
   chomp (my $username = <>);
   print STDERR "Password: ";
   chomp (my $password = <>);
   return ($username,$password);
 }

Note: while processing the authentication callback, processing of
other pending requests will stall, usually at the point at which the
request has been sent, but the results have not yet been received and
parsed.  For this reason, you might want to include a timeout in your
authentication routine.

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
