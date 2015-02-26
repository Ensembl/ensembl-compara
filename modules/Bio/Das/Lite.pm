#########
# Author:        rpettett@cpan.org
# Maintainer:    rpettett@cpan.org
# Created:       2005-08-23
#
package Bio::Das::Lite;
use strict;
use warnings;
use WWW::Curl::Multi;
use WWW::Curl::Easy; # CURLOPT imports
use HTTP::Response;
use Carp;
use English qw(-no_match_vars);
use Readonly;

our $DEBUG    = 0;
our $VERSION  = '2.05';
Readonly::Scalar our $TIMEOUT         => 5;
Readonly::Scalar our $REG_TIMEOUT     => 15;
Readonly::Scalar our $LINKRE          => qr{<link\s+href="([^"]+)"[^>]*?>([^<]*)</link>|<link\s+href="([^"]+)"[^>]*?/>}smix;
Readonly::Scalar our $NOTERE          => qr{<note[^>]*>([^<]*)</note>}smix;
Readonly::Scalar our $DAS_STATUS_TEXT => {
					  200 => '200 OK',
					  400 => '400 Bad command (command not recognized)',
					  401 => '401 Bad data source (data source unknown)',
					  402 => '402 Bad command arguments (arguments invalid)',
					  403 => '403 Bad reference object',
					  404 => '404 Requested object unknown',
					  405 => '405 Coordinate error',
					  500 => '500 Server error',
					  501 => '501 Unimplemented feature',
					 };

#########
# $ATTR contains information about document structure - tags, attributes and subparts
# This is split up by call to reduce the number of tag passes for each response
#
our %COMMON_STYLE_ATTRS = (
			   yoffset        => [], # WTSI extension (available in Ensembl)
			   scorecolormin  => [], # WTSI extension
			   scorecolormax  => [], # WTSI extension
			   scoreheightmin => [], # WTSI extension
			   scoreheightmax => [], # WTSI extension
			   zindex         => [], # WTSI extension (available in Ensembl)
			   width          => [], # WTSI extension (available in Ensembl)
			   height         => [],
			   fgcolor        => [],
			   bgcolor        => [],
			   label          => [],
			   bump           => [],
			  );
our %SCORED_STYLE_ATTRS = (
			   min            => [],
			   max            => [],
			   steps          => [],
			   color1         => [],
			   color2         => [],
			   color3         => [],
			   height         => [],
			  );
our $ATTR     = {
		 '_segment'     => {
				    'segment'      => [qw(id start stop version label)],
				   },
# feature and group notes and links are special cases and taken care of elsewhere
		 'feature'      => {
				    'feature'      => [qw(id label)],
				    'method'       => [qw(id)],
				    'type'         => [qw(id category reference subparts superparts)],
				    'target'       => [qw(id start stop)],
				    'start'        => [],
				    'end'          => [],
				    'orientation'  => [],
				    'phase'        => [],
				    'score'        => [],
				    'group'        => {
						       'group'   => [qw(id label type)],
						       'target'  => [qw(id start stop)],
						      },
				   },
		 'sequence'     => {
				    'sequence'     => [qw(id start stop moltype version)],
				   },
		 'dna'          => {
				    'sequence'     => {
						       'sequence' => [qw(id start stop version)],
						       'dna'      => [qw(length)],
						      },
				   },
		 'entry_points' => {
				    'entry_points' => [qw(href version)],
				    'segment'      => {
						       'segment' => [qw(id start stop type orientation size subparts)],
						      },
				   },
		 'dsn'          => {
				    'dsn'          => [],
				    'source'       => [qw(id)],
				    'mapmaster'    => [],
				    'description'  => [],
				   },
		 'type'         => {
				    'type'         => [qw(id method category)],
				    'segment'      => [qw(id start stop type orientation size subparts)],
				   },
		 'alignment'    => {
				    'alignment'    => [qw(name alignType max)],
				    'alignobject'  => {
						       'alignobject'       => [qw(objVersion
                                                                                  intObjectId
                                                                                  type
                                                                                  dbSource
                                                                                  dbVersion
                                                                                  dbAccessionId
                                                                                  dbCoordSys)],
						       'alignobjectdetail' => {
									       'alignobjectdetail' => [qw(dbSource
                                                                                                          property)],
									      },
						       'sequence'          => [],
						      },
				    'score'        => [qw(score)],
				    'block'        => {
						       'block'   => [qw(blockOrder)],
						       'segment' => {
								     'segment' => [qw(intObjectId
                                                                                      start
                                                                                      end
                                                                                      orientation)],
								     'cigar'   => [],
								    },
						      },
                                 },

		 'structure' => {
				 'object'  => [qw(dbAccessionId
                                                  inObjectId
                                                  objectVersion
                                                  type
                                                  dbSource
                                                  dbVersion
                                                  dbCoordSys)],
				 'chain'   => {
					     'chain' => [qw(id SwissprotId model)],
					     'group' => {
							 'group' => [qw(name type groupID)],
							 'atom'  => {
								     'atom' => [qw(atomID
                                                                                   occupancy
                                                                                   tempFactor
                                                                                   altLoc
                                                                                   atomName
                                                                                   x y z)]
								    },
							},
					     },
				 'het'     => {
					       'group' => {
							   'group' => [qw(name type groupID)],
							   'atom'  => {
								       'atom' => [qw(atomId
                                                                                     occupancy
                                                                                     tempFactor
                                                                                     altLoc
                                                                                     atomName
                                                                                     x y z)]
								      },
							  },
					      },
				 'connect' => {
					       'connect' => [qw(atomSerial type)],
					       'atomID'  => {
							     'atomID' => [qw(atomID)],
							    },
					      },
				},
		 'sources' => {
			       'source' => {
					    'source'     => [qw(uri title doc_href description)],
					    'maintainer' => {
							     'maintainer' => [qw(email)],
							    },
					    'version'    => {
							     'version'     => [qw(uri created)],
							     'coordinates' => {
									       'coordinates' => [qw(uri
                                                                                                    source
                                                                                                    authority
                                                                                                    taxid
                                                                                                    test_range
                                                                                                    version)],
									      },
							     'capability'  => {
									       'capability'  => [qw(type query_uri)],
									      },
							     'prop'        => {
									       'prop'        => [qw(name value)],
									      },
							    },
					   },
			      },
		 'stylesheet'   => {
				    'stylesheet' => [qw(version)],
				    'category'   => {
						     'category' => [qw(id)],
						     'type'     => {
								    'type'  => [qw(id)],
								    'glyph' => {
                                                                                'glyph'          => [qw(zoom)],
										'arrow'          => {
												     'parallel'     => [],
												     'bar_style'    => [], # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'anchored_arrow' => {
												     'parallel'     => [],
												     'orientation'  => [], # WTSI extension
												     'no_anchor'    => [], # WTSI extension
												     'bar_style'    => [], # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'box'            => {
												     'linewidth'    => [],
												     'pattern'      => [],  # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'farrow'         => {                      # WTSI extension
												     'orientation'  => [],
												     'no_anchor'    => [],
												     'bar_style'    => [], # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'rarrow'         => {                      # WTSI extension
												     'orientation'  => [],
												     'no_anchor'    => [],
												     'bar_style'    => [], # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'cross'          => {
												     'linewidth'    => [],  # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'dot'            => \%COMMON_STYLE_ATTRS,
										'ex'             => {
												     'linewidth'    => [],  # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'hidden'         => \%COMMON_STYLE_ATTRS,
										'line'           => {
												     'style'        => [],
												     %COMMON_STYLE_ATTRS,
												    },
										'span'           => {
												     'bar_style'    => [], # WTSI extension
												     %COMMON_STYLE_ATTRS,
												    },
										'text'           => {
												     'font'         => [],
												     'fontsize'     => [],
												     'string'       => [],
												     'style'        => [],
												     %COMMON_STYLE_ATTRS,
												    },
										'primers'        => \%COMMON_STYLE_ATTRS,
										'toomany'        => {
												     'linewidth'    => [],
												     %COMMON_STYLE_ATTRS,
												    },
										'triangle'       => {
												     'linewidth'    => [],
												     'direction'    => [],
												     'orientation'  => [],
												     %COMMON_STYLE_ATTRS,
												    },
										'gradient'       => {
												     %SCORED_STYLE_ATTRS,
												    },
										'histogram'      => {
												     %SCORED_STYLE_ATTRS,
												    },
										'tiling'         => {
												     %SCORED_STYLE_ATTRS,
												    },
										'lineplot'       => {
												     %SCORED_STYLE_ATTRS,
												    },
									       },
								   },
						    },
				   },
		};

#########
# $OPTS contains information about parameters to use for queries
#
our $OPTS = {
	     'feature'      => [qw(segment type category categorize feature_id group_id maxbins)],
	     'type'         => [qw(segment type)],
	     'sequence'     => [qw(segment)],
	     'dna'          => [qw(segment)],
	     'entry_points' => [],
	     'dsn'          => [],
	     'stylesheet'   => [],
             'alignment'    => [qw(query rows subject subjectcoordsys)],
	     'structure'    => [qw(query)],
	    };

sub new {
  my ($class, $ref) = @_;
  $ref    ||= {};
  my $self  = {
	       'dsn'               => [],
	       'timeout'           => $TIMEOUT,
	       'data'              => {},
	       'caching'           => 1,
	       'registry'          => [qw(http://www.dasregistry.org/das)],
	       '_registry_sources' => [],
	      };

  bless $self, $class;

  if($ref && ref $ref) {
    for my $arg (qw(dsn timeout caching callback registry user_agent
                    http_proxy proxy_user proxy_pass no_proxy)) {
      if(exists $ref->{$arg} && $self->can($arg)) {
	$self->$arg($ref->{$arg});
      }
    }
  } elsif($ref) {
    $self->dsn($ref);
  }

  return $self;
}

sub new_from_registry {
  my ($class, $ref) = @_;
  my $user_timeout = defined $ref->{timeout} ? 1 : 0;
  my $self    = $class->new($ref);
  # If the user specifies a timeout, use it.
  # But if not, temporarily increase the timeout for the registry request.
  if (!$user_timeout) {
    $self->timeout($REG_TIMEOUT);
  }
  my $sources = $self->registry_sources($ref);
  # And reset it back to the "normal" non-registry timeout.
  if (!$user_timeout) {
    $self->timeout($TIMEOUT);
  }
  $self->dsn([map { $_->{'url'} } @{$sources}]);
  return $self;
}

# We implement this method because LWP does not parse user/password
sub http_proxy {
  my ($self, $proxy) = @_;
  if($proxy) {
    $self->{'http_proxy'} = $proxy;
  }

  if(!$self->{'_checked_http_proxy_env'}) {
    $self->{'http_proxy'} ||= $ENV{'http_proxy'} || q();
    $self->{'_checked_http_proxy_env'} = 1;
  }

  if($self->{'http_proxy'} =~ m{^(https?://)(\S+):(.*?)\@(.*?)$}smx) {
    #########
    # http_proxy contains username & password - we'll set them up here:
    #
    $self->proxy_user($2);
    $self->proxy_pass($3);

    $self->{'http_proxy'} = "$1$4";
  }

  return $self->{'http_proxy'};
}

sub no_proxy {
  my ($self, @args) = @_;

  if (scalar @args) {
    if ($args[0] && ref $args[0] && ref $args[0] eq 'ARRAY') {
      $self->{'no_proxy'} = $args[0];
    } else {
      $self->{'no_proxy'} = \@args;
    }
  }

  if(!$self->{'_checked_no_proxy_env'}) {
    $self->{'no_proxy'} ||= [split /\s*,\s*/smx, $ENV{'no_proxy'} || q()];
    $self->{'_checked_no_proxy_env'} = 1;
  }

  return $self->{'no_proxy'} || [];
}

sub _get_set {
  my ($self, $key, $value) = @_;
  if(defined $value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub proxy_user {
  my ($self, $val) = @_;
  return $self->_get_set('proxy_user', $val);
}

sub proxy_pass {
  my ($self, $val) = @_;
  return $self->_get_set('proxy_pass', $val);
}

sub user_agent {
  my ($self, $val) = @_;
  return $self->_get_set('user_agent', $val) || "Bio::Das::Lite v$VERSION";
}

sub timeout {
  my ($self, $val) = @_;
  return $self->_get_set('timeout', $val);
}

sub caching {
  my ($self, $val) = @_;
  return $self->_get_set('caching', $val);
}

sub max_hosts {
  my ($self, $val) = @_;
  carp 'WARNING: max_hosts method is decprecated and has no effect';
  return $self->_get_set('_max_hosts', $val);
}

sub max_req {
  my ($self, $val) = @_;
  carp 'WARNING: max_req method is decprecated and has no effect';
  return $self->_get_set('_max_req', $val);
}

sub callback {
  my ($self, $val) = @_;
  return $self->_get_set('callback', $val);
}

sub basename {
  my ($self, $dsn) = @_;
  $dsn           ||= $self->dsn();
  my @dsns         = (ref $dsn)?@{$dsn}:$dsn;
  my @res          = ();

  for my $service (@dsns) {
    $service =~ m{(https?://.*/das)/?}smx;
    if($1) {
      push @res, $1;
    }
  }

  return \@res;
}

sub dsn {
  my ($self, $dsn) = @_;
  if($dsn) {
    if(ref $dsn eq 'ARRAY') {
      $self->{'dsn'} = $dsn;
    } else {
      $self->{'dsn'} = [$dsn];
    }
  }
  return $self->{'dsn'};
}

sub dsns {
  my ($self, $query, $opts) = @_;
  $opts                   ||= {};
  $opts->{'use_basename'}   = 1;
  return $self->_generic_request($query, 'dsn', $opts);
}

sub entry_points {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'entry_points', $opts);
}


sub types {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'type(s)', $opts);
}

sub features {
  my ($self, $query, $callback, $opts) = @_;
  if(ref $callback eq 'HASH' && !defined $opts) {
    $opts = $callback;
    undef $callback;
  }
  if($callback) {
    $self->{'callback'} = $callback;
  }
  return $self->_generic_request($query, 'feature(s)', $opts);
}

sub sequence {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'sequence', $opts);
}

sub dna {
  my ($self, $query, $opts) = @_;
  return $self->_generic_request($query, 'dna', $opts);
}

sub alignment {
  my ($self, $opts) = @_;
  return $self->_generic_request($opts, 'alignment');
}

sub structure {
  my ($self, $opts) = @_;
  return $self->_generic_request($opts, 'structure');
}

sub sources {
  my ($self, $opts) = @_;
  return $self->_generic_request($opts, 'sources');
}

sub stylesheet {
  my ($self, $callback, $opts) = @_;
  if(ref $callback eq 'HASH' && !defined $opts) {
    $opts = $callback;
    undef $callback;
  }
  if($callback) {
    $self->{'callback'} = $callback;
  }
  return $self->_generic_request(undef, 'stylesheet', $opts);
}

#########
# Private methods
#

#########
# Build the query URL; perform an HTTP fetch; drop into the recursive parser; apply any post-processing
#
sub _generic_request {
  my ($self, $query, $fname, $opts) = @_;
  $opts       ||= {};
  delete $self->{'currentsegs'};
  my $results   = {};
  my $reqname   = $fname;
  $reqname      =~ s/(?:[(]|[)])//smxg;
  ($fname)      = $fname =~ /^([[:lower:]_]+)/smx;

  my $ref       = $self->build_requests({
					 query   => $query,
					 fname   => $fname,
					 reqname => $reqname,
					 opts    => $opts,
					 results => $results
					});

  $self->_fetch($ref, $opts->{'headers'});
  $DEBUG and print {*STDERR} qq(Content retrieved\n);

  $self->postprocess($fname, $results);

  #########
  # deal with caching
  #
  if($self->{'caching'}) {
    $DEBUG and print {*STDERR} qq(Performing cache handling\n);
    for my $s (keys %{$results}) {
      if($DEBUG && !$results->{$s}) {
	print {*STDERR} qq(CACHE HIT for $s\n); ## no critic (InputOutput::RequireCheckedSyscalls)
      }
      $results->{$s}          ||= $self->{'_cache'}->{$s};
      $self->{'_cache'}->{$s} ||= $results->{$s};
    }
  }

  return $results;
}

sub build_queries {
  my ($self, $query, $fname) = @_;
  my @queries;

  if($query) {
    if(ref $query eq 'HASH') {
      #########
      # If the query param was a hashref, stitch the parts together
      #
      push @queries, join q(;), map { "$_=$query->{$_}" } grep { $query->{$_} } @{$OPTS->{$fname}};

    } elsif(ref $query eq 'ARRAY') {
      #########
      # If the query param was an arrayref
      #

      if(ref $query->[-1] eq 'CODE') {
	#########
	# ... and the last arg is a code-block, set up the callback for this run and remove the arg
	#
	$self->callback($query->[-1]);
	pop @{$query};
      }

      if(ref $query->[0] eq 'HASH') {
	#########
	# ... or if the first array arg is a hash, stitch the series of queries together
	#
	push @queries, map { ## no critic (ProhibitComplexMappings)
	  my $q = $_;
	  join q(;), map { "$_=$q->{$_}" } grep { $q->{$_} } @{$OPTS->{$fname}};
	} @{$query};

      } else {
	#########
	# ... but otherwise assume it's a plain segment string
	#
	push @queries, map { "segment=$_"; } @{$query};
      }

    } else {
      #########
      # and if it wasn't a hashref or an arrayref, then assume it's a plain segment string
      #
      push @queries, "segment=$query";
    }

  } else {
    #########
    # Otherwise we've no idea what you're trying to do
    #
    push @queries, q();
  }
  return \@queries;
}

sub _hack_fname {
  my ($self, $fname) = @_;
  #########
  # Sucky hacks
  #
  if($fname eq 'structure') {
    $fname = 'dasstructure';
  } elsif($fname eq 'dna') {
    $fname = 'sequence';
  }
  return $fname;
}

sub build_requests {
  my ($self, $args) = @_;
  my $query     = $args->{query};
  my $fname     = $args->{fname};
  my $reqname   = $args->{reqname};
  my $opts      = $args->{opts};
  my $results   = $args->{results};
  my $queries   = $self->build_queries($query, $fname);
  my $attr      = $ATTR->{$fname};
  my $dsn       = $opts->{'use_basename'}?$self->basename():$self->dsn();
  my @bn        = @{$dsn};
  my $ref       = {};

  for my $bn (@bn) {
    #########
    # loop over dsn basenames
    #
    $bn =~ s/\/+$//smx;
    for my $request (map { $_ ? "$bn/$reqname?$_" : "$bn/$reqname" } @{$queries}) {
      #########
      # and for each dsn, loop over the query request
      #

      if($self->{'caching'} && $self->{'_cache'}->{$request}) {
	#########
	# the key has to be present, but the '0' callback will be ignored by _fetch
	#
	$results->{$request} = 0;
	next;
      }

      $results->{$request} = [];
      $ref->{$request}     = sub {
	my $data                     = shift || q();
	$self->{'data'}->{$request} .= $data;

	if(!$self->{'currentsegs'}->{$request}) {
	  #########
	  # If we haven't yet found segment information for this request
	  # Then look for some. This one is a non-destructive scan.
	  #
	  my $matches = $self->{'data'}->{$request}  =~ m{(<segment[^>]*>)}smix;

	  if($matches) {
	    my $seginfo = [];
	    $self->_parse_branch({
				  request    => $request,
				  seginfo    => $seginfo,
				  attr       => $ATTR->{'_segment'},
				  blk        => $1,
				  addseginfo => 0,
				 });
	    $self->{'currentsegs'}->{$request} = $seginfo->[0];
	  }
	}

	if($DEBUG) {
	  print {*STDERR} qq(invoking _parse_branch for $fname\n) or croak $ERRNO;
	}

	#########
	# Sucky hacks
	#
	if($fname eq 'dna') {
	  $attr  = $attr->{'sequence'};
	}
	$fname = $self->_hack_fname($fname);

	my $pat = qr{(<$fname.*?/$fname>|<$fname[^>]+/>)}smix;
	while($self->{'data'}->{$request} =~ s/$pat//smx) {
	  $self->_parse_branch({
				request    => $request,
				seginfo    => $results->{$request},
				attr       => $attr,
				blk        => $1,
				addseginfo => 1,
			       });
	}

	if($DEBUG) {
	  print {*STDERR} qq(completed _parse_branch\n) or croak $ERRNO;
	}

	return;
      };
    }
  }
  return $ref;
}

sub postprocess {
  my ($self, $fname, $results) = @_;

  $fname = $self->_hack_fname($fname);

  #########
  # Add in useful segment information for empty segments
  # In theory there should only ever be one element in @{$self->{'seginfo'}}
  # as requests are parallelised by segment
  #
  for my $req (keys %{$results}) {
    if(!$results->{$req} ||
       scalar @{$results->{$req}} == 0) {
      $results->{$req} = $self->{'currentsegs'}->{$req};
    }
  }

  ## Clean dirty values
  __clean_vals($results);

  #########
  # fix ups
  #
  if($fname eq 'entry_points') {
    $DEBUG and print {*STDERR} qq(Running postprocessing for entry_points\n);

    for my $s (keys %{$results}) {
      my $res = $results->{$s} || [];
      for my $r (@{$res}) {
	delete $r->{'segment_id'};
      }
    }

  } elsif($fname eq 'sequence') {
    $DEBUG and print {*STDERR} qq(Running postprocessing for dna\n);

    for my $s (keys %{$results}) {
      my $res = $results->{$s} || [];

      for my $r (@{$res}) {
	if(exists $r->{'dna'}) {
	  $r->{'dna'} =~ s/\s+//smgx;

	} elsif(exists $r->{'sequence'}) {
	  $r->{'sequence'} =~ s/\s+//smgx;
	}
      }
    }
  }
  return;
}

sub __clean_vals {
  my $object = shift;

  if ($object) {

    my $ref = ref $object;

    if (!$ref) {
      $object =~ s/^[\n\r\t\s]*|[\n\r\t\s]*$//g;
    } elsif ($ref eq 'ARRAY') {
      $object->[$_] = __clean_vals($object->[$_]) for 0..$#$object;
    } elsif ($ref eq 'HASH') {
      $object->{$_} = __clean_vals($object->{$_}) for keys %$object;
    }
  }

  return $object;
}

#########
# Set up the parallel HTTP fetching
# This uses our LWP::Parallel::UserAgent subclass which handles DAS statuses
#
sub _fetch {
  my ($self, $url_ref, $headers) = @_;

  $self->{'statuscodes'} = {};
  if(!$headers) {
    $headers = {};
  }

  # Convert header pairs to strings
  my @headers;
  for my $h (keys %{ $headers }) {
    push @headers, "$h: " . $headers->{$h};
  }

  # We will now issue the actual requests. Due to insufficient support for error
  # handling and proxies, we can't use WWW::Curl::Simple. So we generate a
  # WWW::Curl::Easy object here, and register it with WWW::Curl::Multi.

  my $curlm = WWW::Curl::Multi->new();
  my %reqs;
  my $i = 0;

  # First initiate the requests
  for my $url (keys %{$url_ref}) {
    if(ref $url_ref->{$url} ne 'CODE') {
      next;
    }
    $DEBUG and print {*STDERR} qq(Building WWW::Curl::Easy for $url [timeout=$self->{'timeout'}] via $url_ref->{$url}\n);

    $i++;
    my $curl = WWW::Curl::Easy->new();

    $curl->setopt( CURLOPT_NOPROGRESS, 1 );
    $curl->setopt( CURLOPT_FOLLOWLOCATION, 1 );
    $curl->setopt( CURLOPT_USERAGENT, $self->user_agent );
    $curl->setopt( CURLOPT_URL, $url );

    if (scalar @headers) {
        $curl->setopt( CURLOPT_HTTPHEADER, \@headers );
    }

    my ($body_ref, $head_ref);
    open my $fileb, q[>], \$body_ref or croak 'Error opening data handle'; ## no critic (RequireBriefOpen)
    $curl->setopt( CURLOPT_WRITEDATA, $fileb );

    open my $fileh, q[>], \$head_ref or croak 'Error opening header handle'; ## no critic (RequireBriefOpen)
    $curl->setopt( CURLOPT_WRITEHEADER, $fileh );

    # we set this so we have the ref later on
    $curl->setopt( CURLOPT_PRIVATE, $i );
    $curl->setopt( CURLOPT_TIMEOUT, $self->timeout || $TIMEOUT );
    #$curl->setopt( CURLOPT_CONNECTTIMEOUT, $self->connection_timeout || 2 );

    $self->_fetch_proxy_setup($curl);

    $curlm->add_handle($curl);

    $reqs{$i} = {
                 'uri'  => $url,
                 'easy' => $curl,
                 'head' => \$head_ref,
                 'body' => \$body_ref,
                };
  }

  $DEBUG and print {*STDERR} qq(Requests submitted. Waiting for content\n);

  $self->_receive($url_ref, $curlm, \%reqs);

  return;
}

sub _fetch_proxy_setup {
  my ($self, $curl) = @_;

  if ( my $proxy = $self->http_proxy ) {
    if ( defined $Bio::Das::Lite::{CURLOPT_PROXY} ) {
      $curl->setopt( &CURLOPT_PROXY, $proxy ); ## no critic (ProhibitAmpersandSigils)
    } else {
      croak 'Trying to set a proxy, but your version of libcurl does not support this feature';
    }
  }

  if ( my $proxy_user = $self->proxy_user ) {
    if ( defined $Bio::Das::Lite::{CURLOPT_PROXYUSERNAME} ) {
      $curl->setopt( &CURLOPT_PROXYUSERNAME, $proxy_user ); ## no critic (ProhibitAmpersandSigils)
    } else {
      croak 'Trying to set a proxy username, but your version of libcurl does not support this feature';
    }
  }

  if ( my $proxy_pass = $self->proxy_pass ) {
    if ( defined $Bio::Das::Lite::{CURLOPT_PROXYPASSWORD} ) {
      $curl->setopt( &CURLOPT_PROXYPASSWORD, $proxy_pass ); ## no critic (ProhibitAmpersandSigils)
    } else {
      croak 'Trying to set a proxy password, but your version of libcurl does not support this feature';
    }
  }

  my @no_proxy = @{ $self->no_proxy };
  if ( scalar @no_proxy ) {
    if ( defined $Bio::Das::Lite::{CURLOPT_NOPROXY} ) {
      $curl->setopt( &CURLOPT_NOPROXY, join q(,), @no_proxy ); ## no critic (ProhibitAmpersandSigils)
    } else {
      croak 'Trying to set proxy exclusions, but your version of libcurl does not support this feature';
    }
  }

  return;
}

sub _receive {
  my ($self, $url_ref, $curlm, $reqs) = @_;

  # Now check for results as they come back
  my $i = scalar keys %{ $reqs };
  while ($i) {
    my $active_transfers = $curlm->perform;
    if ($active_transfers != $i) {
      while (my ($id,$retcode) = $curlm->info_read) {
        $id || next;

        $i--;
        my $req  = $reqs->{$id};
        my $uri  = $req->{'uri'};
        my $head = ${ $req->{'head'} } || q();
        my $body = ${ $req->{'body'} } || q();

        # We got a response from the server:
        if ($retcode == 0) {
          my $res = HTTP::Response->parse( $head . "\n" . $body );
          my $msg;

          # Workaround for redirects, which result in multiple headers:
          while ($res->content =~ /^HTTP\/\d+\.\d+\s\d+/mxs) { # check for status line like "HTTP/1.1 200 OK"
            $res = HTTP::Response->parse( $res->content );
          }

          # Prefer X-DAS-Status
          my ($das_status) = ($res->header('X-DAS-Status') || q()) =~ m/^(\d+)/smx;
          if ($das_status) {
            $msg = $self->{statuscodes}->{$uri} = $DAS_STATUS_TEXT->{$das_status};
            # just in case we get a status we don't understand:
            $msg ||= $das_status . q( ) . ($res->message || 'Unknown status');
          }
          # Fall back to HTTP status
          else {
            $msg  = $res->status_line;
            # workaround for bug in HTTP::Response parse method:
            $msg  =~ s/\r//gsmx;
          }

          $self->{statuscodes}->{$uri} = $msg;
          $url_ref->{$uri}->($res->content); # run the content handling code
        }
        # A connection error, timeout etc (NOT an HTTP status):
        else {
          $self->{statuscodes}->{$uri} = '500 ' . $req->{'easy'}->strerror($retcode);
        }

        delete($reqs->{$id}); # put out of scope to free memory
      }
    }
  }

  return;
}

sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};
  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

#########
# Using the $attr structure describing the structure of this branch,
# recursively parse the XML blocks and build the corresponding response data structure
#
sub _parse_branch {
  my ($self, $args) = @_;
  my $dsn           = $args->{request};
  my $ar_ref        = $args->{seginfo};
  my $attr          = $args->{attr};
  my $blk           = $args->{blk};
  my $addseginfo    = $args->{addseginfo};
  my $depth         = $args->{depth} || 0;
  my $ref           = {};

  my (@parts, @subparts);
  while(my ($k, $v) = each %{$attr}) {
    if(ref $v eq 'HASH') {
      push @subparts, $k;
    } else {
      push @parts, $k;
    }
  }

  #########
  # recursive child-node handling, usually for <group>s
  #
  for my $subpart (@subparts) {
    my $subpart_ref  = [];

    my $pat = qr{(<$subpart[^>]*/>|<$subpart[^>]*?(?!/)>.*?/$subpart>)}smix;
    while($blk =~ s/$pat//smx) {
      $self->_parse_branch({
			    request    => $dsn,
			    seginfo    => $subpart_ref,
			    attr       => $attr->{$subpart},
			    blk        => $1,
			    addseginfo => 0,
			    depth      => $depth+1,
			   });
    }

    if(scalar @{$subpart_ref}) {
      $ref->{$subpart} = $subpart_ref;
    }

    #########
    # To-do: normalise group data across features here - mostly for 'group' tags in feature responses
    # i.e. merge links, use cached hashrefs (keyed on group id) describing groups to reduce the parsed tree footprint
    #
  }

  #########
  # Attribute processing for tags in blocks
  #
  my $tmp;
  for my $tag (@parts) {
    my $opts = $attr->{$tag}||[];

    for my $a (@{$opts}) {
      ($tmp)              = $blk =~ m{<$tag[^>]+$a="([^"]+?)"}smix;
      if(defined $tmp) {
	$ref->{"${tag}_$a"} = $tmp;
      }
    }

    ($tmp) = $blk =~ m{<$tag[^>]*>([^<]+)</$tag>}smix;
    if(defined $tmp) {
      $tmp         =~ s/^\s+$//smgx;
      if(length $tmp) {
	$ref->{$tag} = $tmp;
      }
    }
    if($tmp && $DEBUG) {
      print {*STDERR} q( )x($depth*2), qq(  $tag = $tmp\n); ## no critic (InputOutput::RequireCheckedSyscalls)
    }
  }

  $self->_parse_twig($dsn, $blk, $ref, $addseginfo);

  push @{$ar_ref}, $ref;
  $DEBUG and print {*STDERR} q( )x($depth*2), qq(leaving _parse_branch\n);

  #########
  # only perform callbacks if we're at recursion depth zero
  #
  if($depth == 0 && $self->{'callback'}) {
    $DEBUG and print {*STDERR} q( )x($depth*2), qq(executing callback at depth $depth\n);
    $ref->{'dsn'} = $dsn;
    my $callback  = $self->{'callback'};
    &{$callback}($ref);
  }

  return q();
}

sub _parse_twig {
  my ($self, $dsn, $blk, $ref, $addseginfo) = @_;

  #########
  # handle multiples of twig elements here
  #
  $blk =~ s/$LINKRE/{
                     $ref->{'link'} ||= [];
                     push @{$ref->{'link'}}, {
                                              'href' => $1 || $3,
                                              'txt'  => $2,
                                             };
                     q()
                    }/smegix;
  $blk =~ s/$NOTERE/{
                     $ref->{'note'} ||= [];
                     push @{$ref->{'note'}}, $1;
                     q()
                    }/smegix;

  if($addseginfo && $self->{'currentsegs'}->{$dsn}) {
    while(my ($k, $v) = each %{$self->{'currentsegs'}->{$dsn}}) {
      $ref->{$k} = $v;
    }
  }
  return;
}

sub registry {
  my ($self, @reg) = @_;

  if((scalar @reg == 1) &&
     (ref $reg[0])      &&
     (ref$reg[0] eq 'ARRAY')) {
    push @{$self->{'registry'}}, @{$reg[0]};
  } else {
    push @{$self->{'registry'}}, @reg;
  }
  return $self->{'registry'};
}

sub registry_sources {
  my ($self, $filters, $flush) = @_;

  $filters       ||= {};
  my $category     = $filters->{'category'}   || [];
  my $capability   = $filters->{'capability'} || $filters->{'capabilities'} || [];

  if(!ref $category) {
    $category = [$category];
  }

  if(!ref $capability) {
    $capability = [$capability];
  }

  $flush and $self->{'_registry_sources'} = [];

  #########
  # Populate the list of sources if this is the first call or we're flushing
  #
  if (scalar @{$self->{'_registry_sources'}} == 0) {
    $self->_fetch_registry_sources() or return [];
  }

  #########
  # Jump out if there's no filtering to be done
  #
  if(!scalar keys %{$filters}) {
    return $self->{'_registry_sources'};
  }

  my $sources = $self->{'_registry_sources'};

  #########
  # Apply capability filter
  #
  if((ref $capability eq 'ARRAY') &&
     (scalar @{$capability})) {
    my $str    = join q(|), @{$capability};
    my $match  = qr/$str/smx;
    $sources = [grep { $self->_filter_capability($_, $match) } @{$sources}];
  }

  #########
  # Apply coordinatesystem/category filter
  #
  if((ref $category eq 'ARRAY') &&
     (scalar @{$category})) {
    $sources  = [grep { $self->_filter_category($_, $category) } @{$sources}];
  }

  return $sources;
}

sub _fetch_registry_sources {
  my $self     = shift;
  my $reg_urls = $self->registry();

  if (!scalar @{ $reg_urls }) {
    return;
  }

  my $old_dsns     = $self->dsn();
  my $old_statuses = $self->{'statuscodes'};

  $self->dsn($reg_urls);

  #########
  # Run the DAS sources command
  #
  my $sources_ref = $self->sources();
  my $statuses    = $self->{'statuscodes'};

  $self->dsn($old_dsns);
  $self->{'statuscodes'} = $old_statuses;

  for my $url (keys %{ $sources_ref || {} }) {
    my $status = $statuses->{$url} || 'Unknown status';
    if ($status !~ m/^200/mxs) {
      carp "Error fetching sources from '$url' : $status";
      next;
    }

    my $ref = $sources_ref->{$url} || [];

    #########
    # Some basic checks
    #
    (ref $ref eq 'ARRAY') || return;
    $ref = $ref->[0] || {};
    (ref $ref eq 'HASH') || return;
    $ref = $ref->{'source'} || [];
    (ref $ref eq 'ARRAY') || return;

    #########
    # The sources command has sources (really groups of sources) and
    # versions (really individual sources). For compatibility with the
    # old SOAP way of doing things, we must:
    # 1. throw away this source grouping semantic
    # 2. convert the hash format to the old style
    #
    for my $sourcegroup (@{ $ref }) {
      $self->_fetch_registry_sources_sourcegroup($sourcegroup);
    }
  }

  return 1;
}

sub _fetch_registry_sources_sourcegroup {
  my ($self, $sourcegroup) = @_;
  my $versions = $sourcegroup->{'version'} || [];
  (ref $versions eq 'ARRAY') || next;

  for my $source (@{ $versions }) {
    my $caps = $source->{'capability'} || [];
    my $dsn;
    my $object = {
		  capabilities     => [],
		  coordinateSystem => [],
		  description      => $sourcegroup->{source_description},
		  id               => $source->{version_uri},
		 };

    #########
    # Some sources have 'more info' URLs
    #
    if ( my $doc_href = $sourcegroup->{source_doc_href} ) {
      $object->{helperurl} = $doc_href;
    }

    #########
    # Add the capabilties
    #
    for my $cap (@{ $caps }) {
      #########
      # Extract the DAS URL from one of the capabilities
      # NOTE: in DAS 1 we assume all capability query URLs for one
      #       source are the same. Anything else would need the data
      #       model to be redesigned.
      #
      if (!$dsn) {
	$dsn = $cap->{'capability_query_uri'} || q();
	($dsn) = $dsn =~ m{(.+/das\d?/[^/]+)}mxs;
	$object->{'url'} = $dsn;
      }

      my $cap_type = $cap->{'capability_type'} || q();
      ($cap_type)  = $cap_type =~ m/das\d:(.+)/mxs;
      $cap_type || next;

      push @{ $object->{'capabilities'} }, $cap_type;
    }

    #########
    # If none of the capabilities have query URLs, we can't query them!
    #
    $object->{'url'} || next;

    #########
    # Add the coordinates
    #
    my $coords = $source->{'coordinates'} || [];

    for my $coord (@{ $coords }) {
      #########
      # All coordinates have a name and category
      #
      my $coord_ob = {
		      name      => $coord->{coordinates_authority},
		      category  => $coord->{coordinates_source},
		     };

      #########
      # Some coordinates have a version
      #
      if ( my $version = $coord->{'coordinates_version'} ) {
	$coord_ob->{'version'} = $version;
      }

      #########
      # Some coordinates have a species (taxonomy ID and name)
      #
      if ( my $taxid = $coord->{'coordinates_taxid'} ) {
	$coord_ob->{'NCBITaxId'} = $taxid;

	my $desc      = $coord->{'coordinates'};
	my ($species) = $desc =~ m/([^,]+)$/mxs;

	$coord_ob->{'organismName'} = $species;
      }

      #########
      # Add the coordinate system
      #
      push @{ $object->{'coordinateSystem'} }, $coord_ob;
    }

    #########
    # Add the actual source object
    #
    push @{ $self->{'_registry_sources'} }, $object;
  }
  return 1;
}

sub _filter_capability {
  my ($self, $src, $match) = @_;
  for my $scap (@{$src->{'capabilities'}}) {
    if($scap =~ $match) {
      return 1;
    }
  }
  return 0;
};

sub _filter_category {
  my ($self, $src, $match) = @_;
  for my $scoord (@{$src->{'coordinateSystem'}}) {
    for my $m (@{$match}) {
      if ($m =~ m/,/mxs) {
        # regex REQUIRES "authority,type", and handles optional version (with proper underscore handling) and species
        my ($auth, $ver, $cat, $org) = $m =~ m/^ (.+?) (?:_([^_,]+))? ,([^,]+) (?:,(.+))? /mxs;
        if (lc $cat eq lc $scoord->{'category'} &&
            $auth eq $scoord->{'name'} &&
            (!$ver || lc $ver eq lc $scoord->{'version'}) &&
            (!$org || lc $org eq lc $scoord->{'organismName'})) {
          return 1;
        }
      } else {
        return 1 if(lc $scoord->{'category'} eq lc $m);
      }
    }
  }
  return 0;
}

1;
__END__

=head1 NAME

Bio::Das::Lite - Perl extension for the DAS (HTTP+XML) Protocol (http://biodas.org/)

=head1 VERSION

  See $Bio::Das::Lite::VERSION

=head1 SYNOPSIS

  use Bio::Das::Lite;
  my $bdl     = Bio::Das::Lite->new_from_registry({'category' => 'GRCh_37,Chromosome,Homo sapiens'});
  my $results = $bdl->features('22');


=head1 SUBROUTINES/METHODS

=head2 new : Constructor

  my $das = Bio::Das::Lite->new('http://das.ensembl.org/das/ensembl1834');

  my $das = Bio::Das::Lite->new({
			       'timeout'    => 60,
                               'dsn'        => 'http://user:pass@das.ensembl.org/das/ensembl1834',
                               'http_proxy' => 'http://user:pass@webcache.local.com:3128/',
			      });

 Options can be: dsn        (optional scalar or array ref, URLs of DAS services)
                 timeout    (optional int,      HTTP fetch timeout in seconds)
                 http_proxy (optional scalar,   web cache or proxy if not set in %ENV)
                 no_proxy   (optional list/ref, non-proxiable domains if not set in %ENV)
                 caching    (optional bool,     primitive caching on/off)
                 callback   (optional code ref, callback for processed XML blocks)
                 registry   (optional array ref containing DAS registry service URLs
                             defaults to 'http://das.sanger.ac.uk/registry/services/das')
                 proxy_user (optional scalar,   username for authenticating forward-proxy)
                 proxy_pass (optional scalar,   password for authenticating forward-proxy)
                 user_agent (optional scalar,   User-Agent HTTP request header value)

=head2 new_from_registry : Constructor

  Similar to 'new' above but supports 'capability' and 'category'
  in the given hashref, using them to query the DAS registry and
  configuring the DSNs accordingly.

  my $das = Bio::Das::Lite->new_from_registry({
					     'capability' => ['features'],
					     'category'   => ['Protein Sequence'],
					    });

 Options are as above, plus
                 capability OR capabilities   (optional arrayref of capabilities)
                 category                     (optional arrayref of categories)


  For a complete list of capabilities and categories, see:

    http://das.sanger.ac.uk/registry/

  The category can optionally be a full coordinate system name,
  allowing further restriction by authority, version and species.
  For example:
      'Protein Sequence' OR
      'UniProt,Protein Sequence' OR
      'GRCh_37,Chromosome,Homo sapiens'

=head2 http_proxy : Get/Set http_proxy

    $das->http_proxy('http://user:pass@squid.myco.com:3128/');

=head2 proxy_user : Get/Set proxy username for authenticating forward-proxies

  This is only required if the username wasn't specified when setting http_proxy

    $das->proxy_user('myusername');

=head2 proxy_pass : Get/Set proxy password for authenticating forward-proxies

  This is only required if the password wasn't specified when setting http_proxy

    $das->proxy_pass('secretpassword');

=head2 no_proxy : Get/Set domains to not use proxy for

    $das->no_proxy('ebi.ac.uk', 'localhost');
    OR
    $das->no_proxy( ['ebi.ac.uk', 'localhost'] );
    
    Always returns an arrayref

=head2 user_agent : Get/Set user-agent for request headers

    $das->user_agent('GroovyDAS/1.0');

=head2 timeout : Get/Set timeout

    $das->timeout(30);

=head2 caching : Get/Set caching

    $das->caching(1);

=head2 callback : Get/Set callback code ref

    $das->callback(sub { });

=head2 basename : Get base URL(s) of service

    $das->basename(optional $dsn);

=head2 dsn : Get/Set DSN

  $das->dsn('http://das.ensembl.org/das/ensembl1834/'); # give dsn (scalar or arrayref) here if not specified in new()

  Or, if you want to add to the existing dsn list and you're feeling sneaky...

  push @{$das->dsn}, 'http://my.server/das/additionalsource';

=head2 dsns : Retrieve information about other sources served from this server.

 Note this call is 'dsns', as differentiated from 'dsn' which is the current configured source

  my $src_data = $das->dsns();

=head2 entry_points : Retrieve the list of entry_points for this source

  e.g. chromosomes and associated information (e.g. sequence length and version)

  my $entry_points  = $das->entry_points();

=head2 Types of argument for 'types', 'features', 'sequence' calls:

  Segment Id:
  '1'

  Segment Id with range:
  '1:1,1000'

  Segment Id with range and type:
  {
    'segment' => '1:1,1000',
    'type'    => 'exon',
  }

  Multiple Ids with ranges and types:
  [
    {
      'segment' => '1:1,1000',
      'type'    => 'exon',
    },
    {
      'segment' => '2:1,1000',
      'type'    => 'exon',
    },
  ]

  See DAS specifications for other parameters

=head2 types : Find out about different data types available from this source

  my $types         = $das->types(); # takes optional args - see DAS specs

 Retrieve the types of data available for this source
 e.g. 32k_cloneset, karyotype, swissprot

=head2 features : Retrieve features from a segment

   e.g. clones on a chromosome

  #########
  # Different ways to fetch features -
  #
  my $feature_data1 = $das->features('1:1,100000');
  my $feature_data2 = $das->features(['1:1,100000', '2:20435000,21435000']);
  my $feature_data3 = $das->features({
                                      'segment' => '1:1,1000',
                                      'type'    => 'karyotype',
                                      # optional args - see DAS Spec
                                     });
  my $feature_data4 = $das->features([
                                      {'segment'  => '1:1,1000000','type' => 'karyotype',},
                                      {'segment'  => '2:1,1000000',},
                                      {'group_id' => 'OTTHUMG00000036084',},
                                     ]);

  #########
  # Feature fetch with callback
  #
  my $callback = sub {
		      my $struct = shift;
	              print {*STDERR} Dumper($struct);
	             };
  # then:
  $das->callback($callback);
  $das->features('1:1,1000000');

  # or:
  $das->features('1:1,1000000', $callback);

  # or:
  $das->features(['1:1,1000000', '2:1,1000000', '3:1,1000000'], $callback);

  # or:
  $das->features([{'group_id' => 'OTTHUMG00000036084'}, '2:1,1000000', '3:1,1000000'], $callback);

=head2 alignment : Retrieve protein alignment data for a query.  This can be a multiple sequence alignment
                    or pairwise alignment.  Note - this has not been tested for structural alignments as there
                    is currently no Das source avialable.

  my $alignment = $das->alignment({query => 'Q01234'});

=head2 structure : Retrieve known structure (i.e. PDB) for a query

  my $structure = $das->structure({ query => 'pdb_id'});
  
=head2 sources : Retrieves the list of sources form the DAS registry, via a DAS call.

  my $sources = $das->source;  

=head2 sequence : Retrieve sequence data for a segment (probably dna or protein)

  my $sequence      = $das->sequence('2:1,1000'); # segment:start,stop (e.g. chromosome 2, bases 1 to 1000)

=head2 stylesheet : Retrieve stylesheet data

  my $style_data    = $das->stylesheet();
  my $style_data2   = $das->stylesheet($callback);

=head2 statuscodes : Retrieve HTTP status codes for request URLs

  my $code         = $das->statuscodes($url);
  my $code_hashref = $das->statuscodes();

=head2 max_hosts set number of running concurrent host connections

  THIS METHOD IS NOW DEPRECATED AND HAS NO EFFECT

  $das->max_hosts(7);
  print $das->max_hosts();

=head2 max_req set number of running concurrent requests per host

  THIS METHOD IS NOW DEPRECATED AND HAS NO EFFECT

  $das->max_req(5);
  print $das->max_req();

=head2 registry : Get/Set accessor for DAS-Registry service URLs

  $biodaslite->registry('http://www.dasregistry.org/das');

  my $registry_arrayref = $biodaslite->registry();

=head2 registry_sources : Arrayref of dassource objects from the configured registry services

  my $sources_ref = $biodaslite->registry_sources();

  my $sources_ref = $biodaslite->registry_sources({
    'capability' => ['features','stylesheet'],
  });

  my $sources_ref = $biodaslite->registry_sources({
    'category' => ['Protein Sequence'],
  });

=head2 build_queries

Constructs an arrayref of DAS requests including parameters for each call

=head2 build_requests

Constructs the WWW::Curl callbacks

=head2 postprocess

Applies processing to the result set, e.g. removal of whitespace from sequence responses.

=head1 DESCRIPTION

This module is an implementation of a client for the DAS protocol (XML over HTTP primarily for biological-data).

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item WWW::Curl

=item HTTP::Response

=item Carp

=item English

=item Readonly

=back

=head1 DIAGNOSTICS

  Set $Bio::Das::Lite::DEBUG = 1;

=head1 CONFIGURATION AND ENVIRONMENT


=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

  The max_req and max_hosts methods are now deprecated and have no effect.

=head1 SEE ALSO

DAS Specifications at: http://biodas.org/documents/spec.html

ProServer (A DAS Server implementation also by the author) at:
   http://www.sanger.ac.uk/proserver/

The venerable Bio::Das suite (CPAN and http://www.biodas.org/download/Bio::Das/).

The DAS Registry at:
   http://das.sanger.ac.uk/registry/

=head1 AUTHOR

Roger Pettett, E<lt>rpettett@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
