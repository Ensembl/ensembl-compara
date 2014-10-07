#!/usr/local/bin/perl -w
use strict;
#no warnings;

# This is set to where Swish-e's "make install" installed the helper modules.
# use lib ( '@@perlmoduledir@@' );

#
# "prog" document source for spidering web servers
#
# For documentation, type:
#
#       perldoc spider.pl
#
#    Copyright (C) 2001-2003 Bill Moseley swishscript@hank.org
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    as published by the Free Software Foundation; either version
#    2 of the License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    The above lines must remain at the top of this program
#----------------------------------------------------------------------------------

$HTTP::URI_CLASS = "URI";   # prevent loading default URI::URL
                            # so we don't store long list of base items
                            # and eat up memory with >= URI 1.13
use LWP::RobotUA;
use HTML::LinkExtor;
use HTML::Tagset;
use Data::Dumper;

use vars '$bit';
use constant DEBUG_ERRORS   => $bit = 1;    # program errors
use constant DEBUG_URL      => $bit <<= 1;  # print out every URL processes
use constant DEBUG_HEADERS  => $bit <<= 1;  # prints the response headers
use constant DEBUG_FAILED   => $bit <<= 1;  # failed to return a 200
use constant DEBUG_SKIPPED  => $bit <<= 1;  # didn't index for some reason
use constant DEBUG_INFO     => $bit <<= 1;  # more verbose
use constant DEBUG_LINKS    => $bit <<= 1;  # prints links as they are extracted
use constant DEBUG_REDIRECT => $bit <<= 1;  # prints links that are redirected

use constant MAX_REDIRECTS  => 20;  # keep from redirecting forever

my %DEBUG_MAP = (
    errors      => DEBUG_ERRORS,
    url         => DEBUG_URL,
    headers     => DEBUG_HEADERS,
    failed      => DEBUG_FAILED,
    skipped     => DEBUG_SKIPPED,
    info        => DEBUG_INFO,
    links       => DEBUG_LINKS,
    redirect    => DEBUG_REDIRECT,
);

# Valid config file options
my @config_options = qw(
    agent
    base_url
    credentials
    credential_timeout
    debug
    delay_min  (deprecated)
    delay_sec
    email
    filter_content
    get_password
    ignore_robots_file
    keep_alive
    link_tags
    max_depth
    max_files
    max_indexed
    max_size
    max_time
    max_wait_time
    quiet
    remove_leading_dots
    same_hosts
    skip
    spider_done
    test_response
    test_url
    use_cookies
    use_default_config
    use_head_requests
    use_md5
    validate_links
    filter_object
    output_function
);
my %valid_config_options = map { $_ => 1 } @config_options;



use constant MAX_SIZE       => 5_000_000;   # Max size of document to fetch
use constant MAX_WAIT_TIME  => 30;          # request time.

#Can't locate object method "host" via package "URI::mailto" at ../prog-bin/spider.pl line 473.
#sub URI::mailto::host { return '' };


# This is not the right way to do this.
sub UNIVERSAL::host { '' };
sub UNIVERSAL::port { '' };
sub UNIVERSAL::host_port { '' };
sub UNIVERSAL::userinfo { '' };


#-----------------------------------------------------------------------

    use vars '@servers';

    my $config = -e $ARGV[0] && shift || 'SpiderConfig.pl';

    if ( lc( $config ) eq 'default' ) {
        @servers = default_urls();
    } else {
        do $config or die "Failed to read $0 configuration parameters '$config' $! $@";

        die "$0: config file '$config' failed to set \@servers array\n"
            unless @servers;

        die "$0: config file '$config' did not set \@servers array to contain a hash\n"
            unless ref $servers[0] eq 'HASH';


        # Check config options
        for my $server ( @servers ) {
            for ( keys %$server ) {
                warn "$0: ** Warning: config option [$_] is unknown.  Perhaps misspelled?\n"
                    unless $valid_config_options{$_}
            }
        }
    }


    print STDERR "$0: Reading parameters from '$config'\n" unless $ENV{SPIDER_QUIET};

    my $abort;
    local $SIG{HUP} = sub { warn "Caught SIGHUP\n"; $abort++ } unless $^O =~ /Win32/i;

    my %visited;  # global -- I suppose would be smarter to localize it per server.

    my %validated;
    my %bad_links;

    for my $s ( @servers ) {
        if ( !$s->{base_url} ) {
            die "You must specify 'base_url' in your spider config settings\n";
        }

        # Merge in default config?
        $s = { %{ default_config() }, %$s } if $s->{use_default_config};


        # Now, process each URL listed

        my @urls = ref $s->{base_url} eq 'ARRAY' ? @{$s->{base_url}} :( $s->{base_url});
        for my $url ( @urls ) {
            $url = 'http://'.$url unless $url =~ /^http/;
            # purge config options -- used when base_url is an array
            $valid_config_options{$_} ||  delete $s->{$_} for keys %$s;

            $s->{base_url} = $url;
            process_server( $s );
        }
    }


    if ( %bad_links ) {
        print STDERR "\nBad Links:\n\n";
        foreach my $page ( sort keys %bad_links ) {
            print STDERR "On page: $page\n";
            printf(STDERR " %-40s  %s\n", $_, $validated{$_} ) for @{$bad_links{$page}};
            print STDERR "\n";
        }
    }


#==================================================================================
# process_server()
#
# This processes a single server config (part of @servers)
# It validates and cleans up the config and then starts spidering
# for each URL listed in base_url
#
#----------------------------------------------------------------------------------


sub process_server {
    my $server = shift;



    # set defaults


    # Set debug options.
    $server->{debug} =
        defined $ENV{SPIDER_DEBUG}
            ? $ENV{SPIDER_DEBUG}
            : ($server->{debug} || 0);

    # Convert to number
    if ( $server->{debug} !~ /^\d+$/ ) {
        my $debug = 0;
        $debug |= (exists $DEBUG_MAP{lc $_} 
            ? $DEBUG_MAP{lc $_} 
            : die "Bad debug setting passed in "
                    . (defined $ENV{SPIDER_DEBUG} ? 'SPIDER_DEBUG environment' : q['debug' config option])
                    . " '$_'\nOptions are: " 
                    . join( ', ', sort keys %DEBUG_MAP) ."\n")
        for split /\s*,\s*/, $server->{debug};
        $server->{debug} = $debug;
    }



    $server->{quiet} ||= $ENV{SPIDER_QUIET} || 0;


    # Lame Microsoft
    $URI::ABS_REMOTE_LEADING_DOTS = $server->{remove_leading_dots} ? 1 : 0;

    $server->{max_size} = MAX_SIZE unless defined $server->{max_size};
    die "max_size parameter '$server->{max_size}' must be a number\n" unless $server->{max_size} =~ /^\d+$/;


    $server->{max_wait_time} ||= MAX_WAIT_TIME;
    die "max_wait_time parameter '$server->{max_wait_time}' must be a number\n" if $server->{max_wait_time} !~ /^\d+$/;

    # Can be zero or undef or a number.
    $server->{credential_timeout} = 30 unless exists $server->{credential_timeout};
    die "credential_timeout '$server->{credential_timeout}' must be a number\n" if defined $server->{credential_timeout} && $server->{credential_timeout} !~ /^\d+$/;





    $server->{link_tags} = ['a'] unless ref $server->{link_tags} eq 'ARRAY';
    $server->{link_tags_lookup} = { map { lc, 1 } @{$server->{link_tags}} };

    die "max_depth parameter '$server->{max_depth}' must be a number\n" if defined $server->{max_depth} && $server->{max_depth} !~ /^\d+/;


    for ( qw/ test_url test_response filter_content/ ) {
        next unless $server->{$_};
        $server->{$_} = [ $server->{$_} ] unless ref $server->{$_} eq 'ARRAY';
        my $n;
        for my $sub ( @{$server->{$_}} ) {
            $n++;
            die "Entry number $n in $_ is not a code reference\n" unless ref $sub eq 'CODE';
        }
    }



    my $start = time;

    if ( $server->{skip} ) {
        print STDERR "Skipping Server Config: $server->{base_url}\n" unless $server->{quiet};
        return;
    }

    require "HTTP/Cookies.pm" if $server->{use_cookies};
    require "Digest/MD5.pm" if $server->{use_md5};


    # set starting URL, and remove any specified fragment
    my $uri = URI->new( $server->{base_url} );
    $uri->fragment(undef);

    if ( $uri->userinfo ) {
        die "Can't specify parameter 'credentials' because base_url defines them\n"
            if $server->{credentials};
        $server->{credentials} = $uri->userinfo;
        $uri->userinfo( undef );
    }


    print STDERR "\n -- Starting to spider: $uri --\n" if $server->{debug};



    # set the starting server name (including port) -- will only spider on server:port


    # All URLs will end up with this host:port
    $server->{authority} = $uri->canonical->authority;

    # All URLs must match this scheme ( Jan 22, 2002 - spot by Darryl Friesen )
    $server->{scheme} = $uri->scheme;



    # Now, set the OK host:port names
    $server->{same} = [ $uri->canonical->authority || '' ];

    push @{$server->{same}}, @{$server->{same_hosts}} if ref $server->{same_hosts};

    $server->{same_host_lookup} = { map { $_, 1 } @{$server->{same}} };




    # set time to end

    $server->{max_time} = $server->{max_time} * 60 + time
        if $server->{max_time};


    # set default agent for log files

    $server->{agent} ||= 'swish-e http://swish-e.org/';


    # get a user agent object


    my $ua;


    # set the delay
    unless ( defined $server->{delay_sec} ) {
        if ( defined $server->{delay_min} && $server->{delay_min} =~ /^\d+\.?\d*$/ ) {
            # change if ever move to Time::HiRes
            $server->{delay_sec} = int ($server->{delay_min} * 60);
        }

        $server->{delay_sec} = 5 unless defined $server->{delay_sec};
    }
    $server->{delay_sec} = 5 unless $server->{delay_sec} =~ /^\d+$/;


    if ( $server->{ignore_robots_file} ) {
        $ua = LWP::UserAgent->new;
        return unless $ua;
        $ua->agent( $server->{agent} );
        $ua->from( $server->{email} );

    } else {
        $ua = LWP::RobotUA->new( $server->{agent}, $server->{email} );
        return unless $ua;
        $ua->delay( 0 );  # handle delay locally.
    }

    # If ignore robots files also ignore meta ignore <meta name="robots">
    # comment out so can find http-equiv charset
    # $ua->parse_head( 0 ) if $server->{ignore_robots_file} || $server->{ignore_robots_headers};


    # Set the timeout - used to only for windows and used alarm, but this
    # did not always works correctly.  Hopefully $ua->timeout works better in
    # current versions of LWP (before DNS could block forever)

    $ua->timeout( $server->{max_wait_time} );



    $server->{ua} = $ua;  # save it for fun.
    # $ua->parse_head(0);   # Don't parse the content

    $ua->cookie_jar( HTTP::Cookies->new ) if $server->{use_cookies};

    if ( $server->{keep_alive} ) {

        if ( $ua->can( 'conn_cache' ) ) {
            my $keep_alive = $server->{keep_alive} =~ /^\d+$/ ? $server->{keep_alive} : 1;
            $ua->conn_cache( { total_capacity => $keep_alive } );

        } else {
            delete $server->{keep_alive};
            warn "Can't use keep-alive: conn_cache method not available\n";
        }
    }

    # Disable HEAD requests if there's no reason to use them
    # Keep_alives is questionable because even without keep alives
    # it might be faster to do a HEAD than a partial GET.

    if ( $server->{use_head_requests} && !$server->{keep_alive} ||
        !( $server->{test_response} || $server->{max_size} ) ) {

        warn 'Option "use_head_requests" was disabled.\nNeed keep_alive and either test_response or max_size options\n';
        delete $server->{use_head_requests};
    }


    # uri, parent, depth
    eval { spider( $server, $uri ) };
    print STDERR $@ if $@;


    # provide a way to call a function in the config file when all done
    check_user_function( 'spider_done', undef, $server );


    delete $server->{ua};  # Free up LWP to avoid CLOSE_WAITs hanging around when using a lot of @servers.

    return if $server->{quiet};


    $start = time - $start;
    $start++ unless $start;

    my $max_width = 0;
    my $max_num = 0;
    for ( keys %{$server->{counts}} ) {
        $max_width = length if length > $max_width;
        my $val = commify( $server->{counts}{$_} );
        $max_num = length $val if length $val > $max_num;
    }


    print STDERR "\nSummary for: $server->{base_url}\n";

    for ( sort keys %{$server->{counts}} ) {
        printf STDERR "%${max_width}s: %${max_num}s  (%0.1f/sec)\n",
            $_,
            commify( $server->{counts}{$_} ),
            $server->{counts}{$_}/$start;
    }
}


#-----------------------------------------------------------------------
# Deal with Basic Authen



# Thanks Gisle!
sub get_basic_credentials {
    my($uri, $server, $realm ) = @_;

    # Exists but undefined means don't ask.
    return if exists $server->{credential_timeout} && !defined $server->{credential_timeout};

    # Exists but undefined means don't ask.

    my $netloc = $uri->canonical->host_port;

    my ($user, $password);

    eval {
        local $SIG{ALRM} = sub { die "timed out\n" };

        # a zero timeout means don't time out
        alarm( $server->{credential_timeout} ) unless $^O =~ /Win32/i;

        if (  $uri->userinfo ) {
            print STDERR "\nSorry: invalid username/password\n";
            $uri->userinfo( undef );
        }


        print STDERR "Need Authentication for $uri at realm '$realm'\n(<Enter> skips)\nUsername: ";
        $user = <STDIN>;
        chomp($user) if $user;
        die "No Username specified\n" unless length $user;

        alarm( $server->{credential_timeout} ) unless $^O =~ /Win32/i;

        print STDERR "Password: ";
        system("stty -echo");
        $password = <STDIN>;
        system("stty echo");
        print STDERR "\n";  # because we disabled echo
        chomp($password);
        alarm( 0 ) unless $^O =~ /Win32/i;
    };

    alarm( 0 ) unless $^O =~ /Win32/i;

    return if $@;

    return join ':', $user, $password;


}




#----------- Non recursive spidering ---------------------------
# Had problems with some versions of LWP where memory was not freed
# after the URI objects went out of scope, so instead just maintain
# a list of URI.
# Should move this to a DBM or database.

sub spider {
    my ( $server, $uri ) = @_;

    # Validate the first link, just in case
    return unless check_link( $uri, $server, '', '(Base URL)' );

    my @link_array = [ $uri, '', 0 ];

    while ( @link_array ) {

        die $server->{abort} if $abort || $server->{abort};

        my ( $uri, $parent, $depth ) = @{shift @link_array};

        delay_request( $server );

        # Delete any per-request data
        delete $server->{_request};

        my $new_links = process_link( $server, $uri->clone, $parent, $depth );
        push @link_array, map { [ $_, $uri, $depth+1 ] } @$new_links if $new_links;

    }
}

#---------- Delay a request based on the delay time -------------

sub delay_request {
    my ( $server ) = @_;


    # Here's a place to log the type of connection

    if ( $server->{keep_alive_connection} ) {
        $server->{counts}{'Connection: Keep-Alive'}++;
        # no delay on keep-alives
        return;
    }

    $server->{counts}{'Connection: Close'}++;

    # return if no delay or first request
    return if !$server->{delay_sec} || !$server->{last_response_time};



    my $wait = $server->{delay_sec} - ( time - $server->{last_response_time} );

    return unless $wait > 0;

    print STDERR "sleeping $wait seconds\n" if $server->{debug} & DEBUG_URL;
    sleep( $wait );
}


#================================================================================
# process_link()  - process a link from the list
#
# Can be called recursively (for auth and redirects)
#
# This does most of the work.
# Pass in:
#   $server -- config hash, plus ugly scratch pad memory
#   $uri    -- uri to fetch and extract links from
#   $parent -- parent uri for better messages
#   $depth  -- for controlling how deep to go into a site, whatever that means
#
# Returns:
#   undef or an array ref of links to add to the list
#
# Makes request, tests response, logs, parsers and extracts links
# Very ugly as this is some of the oldest code
#
#---------------------------------------------------------------------------------

sub process_link {
    my ( $server, $uri, $parent, $depth ) = @_;

    $server->{counts}{'Unique URLs'}++;

    die "$0: Max files Reached\n"
        if $server->{max_files} && $server->{counts}{'Unique URLs'} > $server->{max_files};

    die "$0: Time Limit Exceeded\n"
        if $server->{max_time} && $server->{max_time} < time;


    # clean up some per-request rubbish.
    # Really should just subclass the response object!
    $server->{no_contents} = 0;
    $server->{no_index} = 0;
    $server->{no_spider} = 0;



    # Make request object for this URI

    my $request = HTTP::Request->new('GET', $uri );

    ## HTTP::Message uses Compress::Zlib, and Gisle responded Jan 8, 07 that it's safe to test
    my @encodings;
    eval { require Compress::Zlib };
    push @encodings, qw/gzip x-gzip deflate/ unless $@;

    eval { require Compress::Bzip2 };
    push @encodings, 'x-bzip2' unless $@;

    $request->header('Accept-encoding', join ', ', @encodings ) if @encodings;


    $request->header('Referer', $parent ) if $parent;


    # Set basic auth if defined - use URI specific first, then credentials
    # this doesn't track what should have authorization
    my $last_auth;
    if ( $server->{last_auth} ) {
        my $path = $uri->path;
        $path =~ s!/[^/]*$!!;
        $last_auth = $server->{last_auth}{auth} if $server->{last_auth}{path} eq $path;
    }


    if ( my ( $user, $pass ) = split /:/, ( $last_auth || $uri->userinfo || $server->{credentials} || '' ) ) {
        $request->authorization_basic( $user, $pass );
    }


    my $response;


    delete $server->{response_checked};  # to keep from checking more than once


    if ( $server->{use_head_requests} ) {
        $request->method('HEAD');

        # This is ugly in what it can return.  It's can be recursive.
        $response = make_request( $request, $server, $uri, $parent, $depth );

        return $response if !$response || ref $response eq 'ARRAY';  # returns undef or an array ref if done

        # otherwise, we have a response object.

        $request->method('GET');
    }


    # Now make GET request
    $response = make_request( $request, $server, $uri, $parent, $depth );
    return $response if !$response || ref $response eq 'ARRAY';  # returns undef or an array ref


    # Now we have a $response object with content

    return process_content( $response, $server, $uri, $parent, $depth );

}


#===================================================================================
# make_request -- 
#
# This only can deal with things that happen in a HEAD request.
# Well, unless test for the method
#
# Hacke up function to make either a HEAD or GET request and test the response
# Returns one of three things:
#   undef - stop processing and return
#   and array ref - a list of URLs extracted (via recursive call)
#   a HTTP::Response object
#
#
# Yes it's a mess -- got pulled out of other code when adding HEAD requests
#-----------------------------------------------------------------------------------

sub make_request {
    my ( $request, $server, $uri, $parent, $depth ) = @_;

    my $response;
    my $response_aborted_msg;
    my $killed_connection;

    my $ua = $server->{ua};

    if ( $request->method eq 'GET' ) {

        # When making a GET request this gets called for every chunk returned
        # from the webserver (well, from the OS).  No idea how bit it will be.
        #
        my $total_length = 0;

        my $callback = sub {
            my ( $content, $response ) = @_;
            # First time, check response - this can die()
            check_response( $response, $server, $uri, $parent )
                unless $server->{response_checked}++;


            # In case didn't return a content-length header
            $total_length += length $content;
            check_too_big( $response, $server, $total_length ) if $server->{max_size};



            $response->add_content( $content );
        };

        ## Make Request ##

        # Used to wrap in an eval and use alarm on non-win32 to fix broken $ua->timeout

        $response = $ua->simple_request( $request, $callback, 4096 );

        # Check for callback death:
        # If the LWP callback aborts

        if ( $response->header('client-aborted') ) {
            $response_aborted_msg = $response->header('X-Died') || 'unknown';
            $killed_connection++;  # so we will delay
        }

    } else {

        # Make a HEAD request
        $response = $ua->simple_request( $request );

        # check_response - user callback can call die() so wrap in eval block
        eval {
            check_response( $response, $server, $uri, $parent )
                unless $server->{response_checked}++;
        };
        $response_aborted_msg = $@ if $@;
    }

    # save the request completion time for delay between requests
    $server->{last_response_time} = time;


    # Ok, did the request abort for some reason?  (response checker called die() )

    if ( $response_aborted_msg ) {
        # Log unless it's the callback (because the callback already logged it)
        if ( $response_aborted_msg !~ /test_response/ ) {
            $server->{counts}{Skipped}++;

            # Not really sure why request aborted.  Let's try and make the error message
            # a bit cleaner.
            print STDERR "Request for '$uri' aborted because: '$response_aborted_msg'\n" if $server->{debug}&DEBUG_SKIPPED;
        }


        # Aborting in the callback breaks the connection (so tested on Apache)
        # even if all the data was transmitted.
        # Might be smart to flag to abort but wait until the next chunk
        # to really abort.  That might make so the connection would not get killed.

        delete $server->{keep_alive_connection} if $killed_connection;
        return;
    }



    # Look for connection.  Assume it's a keep-alive unless we get a Connection: close
    # header.  Some server errors (on Apache) will close the connection, but they
    # report it.
    # Have to assume the connection is open (without asking LWP) since the first 
    # connection we normally do not see (robots.txt) and then following keep-alive
    # connections do not have Connection: header.

    my $connection = $response->header('Connection') || 'Keep-alive';  # assume keep-alive
    $server->{keep_alive_connection} =  !$killed_connection && $server->{keep_alive} && $connection !~ /close/i;



    # Did a callback return abort?
    return if $server->{abort};


    # Clean up the URI so passwords don't leak

    $response->request->uri->userinfo( undef ) if $response->request;
    $uri->userinfo( undef );

    # A little debugging
    print STDERR "\nvvvvvvvvvvvvvvvv HEADERS for $uri vvvvvvvvvvvvvvvvvvvvv\n\n---- Request ------\n",
                  $response->request->as_string,
                  "\n---- Response ---\nStatus: ", $response->status_line,"\n",
                  $response->headers->as_string,
                  "\n^^^^^^^^^^^^^^^ END HEADERS ^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n"
       if $server->{debug} & DEBUG_HEADERS;



    # Deal with failed responses
    #
    #    return failed_response( $response, $server, $uri, $parent, $depth )
    #        unless $response->is_success;


    # Don't log HEAD requests
    return $request if $request->method eq 'HEAD';

    # Log if requested

    log_response( $response, $server, $uri, $parent, $depth )
        if $server->{debug} & DEBUG_URL;



    # Check for meta refresh
    # requires that $ua->parse_head() is enabled (the default)

    return redirect_response( $response, $server, $uri, $parent, $depth, $1, 'meta refresh' )
        if $response->header('refresh') && $response->header('refresh') =~ /URL\s*=\s*(.+)/;


    return $response;
}


#===================================================================
# check_response -- after resonse comes back from server
#
# Failure here should die() because check_user_function can die()
#
#-------------------------------------------------------------------
sub check_response {
    my ( $response, $server, $uri, $parent ) = @_;

    #return unless $response->is_success;  # 2xx response.

    # Cache user/pass if entered from the keyboard or callback function (as indicated by the realm)
    # do here so we know it is correct

    if ( $server->{cur_realm} && $uri->userinfo ) {
        my $key = $uri->canonical->host_port . ':' . $server->{cur_realm};
        $server->{auth_cache}{$key} =  $uri->userinfo;

        # not too sure of the best logic here
        my $path = $uri->path;
        $path =~ s!/[^/]*$!!;
        $server->{last_auth} = {
            path => $path,
            auth => $uri->userinfo,
        };
    }

    # check for document too big.
    check_too_big( $response, $server ) if $server->{max_size};

    die "test_response" if !check_user_function( 'test_response', $uri, $server, $response, $parent );

}

#=====================================================================
# check_too_big -- see if document is too big
# Die if it is too big.
#--------------------------------------------------------------------

sub check_too_big {
    my ( $response, $server, $length ) = @_;

    $length ||= $response->content_length || 0;
    return unless $length && $length =~ /^\d+$/;

    die "Document exceeded $server->{max_size} bytes (Content-Length: $length) Method: " . $response->request->method . "\n"
        if $length > $server->{max_size};
}

#=========================================================================
# failed_response -- deal with a non 2xx response
#
#------------------------------------------------------------------------
sub failed_response {
    my ( $response, $server, $uri, $parent, $depth ) = @_;

    my $links;

    # Do we need to authorize?
    if ( $response->code == 401 ) {
        # This will log the error
        $links = authorize( $response, $server, $uri, $parent, $depth );
        return $links if ref $links or !$links;
    }


    # Are we rejected because of robots.txt?

    if ( $response->status_line =~ 'robots.txt' ) {
        print STDERR "-Skipped $depth $uri: ", $response->status_line,"\n" if $server->{debug}&DEBUG_SKIPPED;
        $server->{counts}{'robots.txt'}++;
        return;
    }


    # Look for redirect
    return redirect_response( $response, $server, $uri, $parent, $depth )
        if $response->is_redirect;

    # Report bad links (excluding those skipped by robots.txt)
    # Not so sure about this being here for these links...
    validate_link( $server, $uri, $parent, $response )
        if $server->{validate_links};


    # Otherwise, log if needed and then return.
    log_response( $response, $server, $uri, $parent, $depth )
        if $server->{debug} & DEBUG_FAILED;

    return;
}


#=============================================================================
# redirect_response -- deal with a 3xx redirect
#
# Returns link to follow
#
#----------------------------------------------------------------------------
sub redirect_response {
    my ( $response, $server, $uri, $parent, $depth, $location, $description ) = @_;

    $location ||= $response->header('location');
    unless ( $location ) {
        print STDERR "Warning: $uri returned a redirect without a Location: header\n";
        return;
    }

    $description ||= 'Location';


    # This should NOT be needed, but some servers are broken
    # and don't return absolute links.
    # and this may even break things
    my $u = URI->new_abs( $location, $response->base );

    if ( $u->canonical eq $uri->canonical ) {
        print STDERR "Warning: $uri redirects to itself!.\n";
        return;
    }

    # make sure it's ok:
    return unless check_link( $u, $server, $response->base, '(redirect)', $description  );


    # make recursive request
    # This will not happen because the check_link records that the link has been seen.
    # But leave here just in case

    if ( $server->{_request}{redirects}++ > MAX_REDIRECTS ) {
        warn "Exceeded redirect limit: perhaps a redirect loop: $uri on parent page: $parent\n";
        return;
    }

    print STDERR "--Redirect: $description $uri -> $u. Parent: $parent\n" if $server->{debug} & DEBUG_REDIRECT;

    $server->{counts}{"$description Redirects"}++;
    my $links = process_link( $server, $u, $parent, $depth );
    $server->{_request}{redirects}-- if  $server->{_request}{redirects};
    return $links;

}

#=================================================================================
# Do we need to authorize?  If so, ask for password and request again.
# First we try using any cached value
# Then we try using the get_password callback
# Then we ask.

sub authorize {
    my ( $response, $server, $uri, $parent, $depth ) = @_;


    delete $server->{last_auth};  # since we know that doesn't work


    if ( $response->header('WWW-Authenticate') && $response->header('WWW-Authenticate') =~ /realm="([^"]+)"/i ) {
        my $realm = $1;
        my $user_pass;

        # Do we have a cached user/pass for this realm?
        unless ( $server->{_request}{auth}{$uri}++ ) { # only each URI only once
            my $key = $uri->canonical->host_port . ':' . $realm;

            if ( $user_pass = $server->{auth_cache}{$key} ) {

                # If we didn't just try it, try again
                unless( $uri->userinfo && $user_pass eq $uri->userinfo ) {

                    # add the user/pass to the URI
                    $uri->userinfo( $user_pass );
                    return process_link( $server, $uri, $parent, $depth );
                }
            }
        }

        # now check for a callback password (if $user_pass not set)
        unless ( $user_pass || $server->{_request}{auth}{callback}++ ) {

            # Check for a callback function
            $user_pass = $server->{get_password}->( $uri, $server, $response, $realm )
                if ref $server->{get_password} eq 'CODE';
        }

        # otherwise, prompt (over and over)

        if ( !$user_pass ) {
            $user_pass = get_basic_credentials( $uri, $server, $realm );
        }


        if ( $user_pass ) {
            $uri->userinfo( $user_pass );
            $server->{cur_realm} = $realm;  # save so we can cache if it's valid
            my $links = process_link( $server, $uri, $parent, $depth );
            delete $server->{cur_realm};
            return $links;
        }
    }

    log_response( $response, $server, $uri, $parent, $depth )
        if $server->{debug} & DEBUG_FAILED;

    return;  # Give up
}




#==================================================================================
# Log a response

sub log_response {
    my ( $response, $server, $uri, $parent, $depth ) = @_;

    # Log the response

    print STDERR '>> ',
      join( ' ',
            ( $response->is_success ? '+Fetched' : '-Failed' ),
            $depth,
            "Cnt: $server->{counts}{'Unique URLs'}",
            $response->request->method,
            " $uri ",
            ( $response->status_line || $response->status || 'unknown status' ),
            ( $response->content_type || 'Unknown content type'),
            ( $response->content_length || '???' ),
            "parent:$parent",
            "depth:$depth",
       ),"\n";
}

#===================================================================================================
#  Calls a user-defined function
#
#---------------------------------------------------------------------------------------------------

sub check_user_function {
    my ( $fn, $uri, $server, @args ) = @_;

    return 1 unless $server->{$fn};

    my $tests = ref $server->{$fn} eq 'ARRAY' ? $server->{$fn} : [ $server->{$fn} ];

    my $cnt;

    for my $sub ( @$tests ) {
        $cnt++;
        print STDERR "?Testing '$fn' user supplied function #$cnt '$uri'\n" if $server->{debug} & DEBUG_INFO;

        my $ret;

        eval { $ret = $sub->( $uri, $server, @args ) };

        if ( $@ ) {
            print STDERR "-Skipped $uri due to '$fn' user supplied function #$cnt death '$@'\n" if $server->{debug} & DEBUG_SKIPPED;
            $server->{counts}{Skipped}++;
            return;
        }

        next if $ret;

        print STDERR "-Skipped $uri due to '$fn' user supplied function #$cnt\n" if $server->{debug} & DEBUG_SKIPPED;
        $server->{counts}{Skipped}++;
        return;
    }
    print STDERR "+Passed all $cnt tests for '$fn' user supplied function\n" if $server->{debug} & DEBUG_INFO;
    return 1;
}

#==============================================================================
# process_content -- deals with a response object.  Kinda
#
# returns an array ref of new links to follow
#
#-----------------------------------------------------------------------------

sub process_content { 
    my ( $response, $server, $uri, $parent, $depth ) = @_;


    # Check for meta robots tag
    # -- should probably be done in request sub to avoid fetching docs that are not needed
    # -- also, this will not not work with compression $$$ check this

    unless ( $server->{ignore_robots_file}  || $server->{ignore_robots_headers} ) {
        if ( my $directives = $response->header('X-Meta-ROBOTS') ) {
            my %settings = map { lc $_, 1 } split /\s*,\s*/, $directives;
            $server->{no_contents}++ if exists $settings{nocontents};  # an extension for swish
            $server->{no_index}++    if exists $settings{noindex};
            $server->{no_spider}++   if exists $settings{nofollow};
        }
    }

    # make sure content is unique - probably better to chunk into an MD5 object above

    if ( $server->{use_md5} ) {
        my $digest =  $response->header('Content-MD5') || Digest::MD5::md5($response->content);
        if ( $visited{ $digest } ) {

            print STDERR "-Skipped $uri has same digest as $visited{ $digest }\n"
                if $server->{debug} & DEBUG_SKIPPED;

            $server->{counts}{Skipped}++;
            $server->{counts}{'MD5 Duplicates'}++;
            return;
        }
        $visited{ $digest } = $uri;
    }



    my $content = $response->decoded_content;

    unless ( $content ) {
        my $empty = '';
        output_content( $server, \$empty, $uri, $response )
            unless $server->{no_index};
        return;
    }

    # Extract out links (if not too deep)

    my $links_extracted = extract_links( $server, \$content, $response )
        unless defined $server->{max_depth} && $depth >= $server->{max_depth};


    # Index the file

    if ( $server->{no_index} ) {
        $server->{counts}{Skipped}++;
        print STDERR "-Skipped indexing $uri some callback set 'no_index' flag\n" if $server->{debug}&DEBUG_SKIPPED;

    } else {
        return $links_extracted unless check_user_function( 'filter_content', $uri, $server, $response, \$content );

        output_content( $server, \$content, $uri, $response )
            unless $server->{no_index};
    }



    return $links_extracted;
}


#==============================================================================================
#  Extract links from a text/html page
#
#   Call with:
#       $server - server object
#       $content - ref to content
#       $response - response object
#
#----------------------------------------------------------------------------------------------

sub extract_links {
    my ( $server, $content, $response ) = @_;

    return unless $response->header('content-type') &&
                     $response->header('content-type') =~ m[^text/html];

    # allow skipping.
    if ( $server->{no_spider} ) {
        print STDERR '-Links not extracted: ', $response->request->uri->canonical, " some callback set 'no_spider' flag\n" if $server->{debug}&DEBUG_SKIPPED;
        return;
    }

    $server->{Spidered}++;

    my @links;


    my $base = $response->base;
    $visited{ $base }++;  # $$$ come back and fix this (see 4/20/03 lwp post)


    print STDERR "\nExtracting links from ", $response->request->uri, ":\n" if $server->{debug} & DEBUG_LINKS;

    my $p = HTML::LinkExtor->new;
    $p->parse( $$content );

    my %skipped_tags;

    for ( $p->links ) {
        my ( $tag, %attr ) = @$_;

        # which tags to use ( not reported in debug )

        my $attr = join ' ', map { qq[$_="$attr{$_}"] } keys %attr;

        print STDERR "\nLooking at extracted tag '<$tag $attr>'\n" if $server->{debug} & DEBUG_LINKS;

        unless ( $server->{link_tags_lookup}{$tag} ) {

            # each tag is reported only once per page
            print STDERR
                "   <$tag> skipped because not one of (",
                join( ',', @{$server->{link_tags}} ),
                ")\n" if $server->{debug} & DEBUG_LINKS && !$skipped_tags{$tag}++;

            if ( $server->{validate_links} && $tag eq 'img' && $attr{src} ) {
                my $img = URI->new_abs( $attr{src}, $base );
                validate_link( $server, $img, $base );
            }

            next;
        }

        # Grab which attribute(s) which might contain links for this tag
        my $links = $HTML::Tagset::linkElements{$tag};
        $links = [$links] unless ref $links;


        my $found;


        # Now, check each attribut to see if a link exists

        for my $attribute ( @$links ) {
            if ( $attr{ $attribute } ) {  # ok tag

                # Create a URI object

                my $u = URI->new_abs( $attr{$attribute},$base );

                next unless check_link( $u, $server, $base, $tag, $attribute );

                push @links, $u;
                print STDERR qq[   $attribute="$u" Added to list of links to follow\n] if $server->{debug} & DEBUG_LINKS;
                $found++;
            }
        }


        if ( !$found && $server->{debug} & DEBUG_LINKS ) {
            print STDERR "  tag did not include any links to follow or is a duplicate\n";
        }

    }

    print STDERR "! Found ", scalar @links, " links in ", $response->base, "\n\n" if $server->{debug} & DEBUG_INFO;


    return \@links;
}




#=============================================================================
# This function check's if a link should be added to the list to spider
#
#   Pass:
#       $u - URI object
#       $server - the server hash
#       $base - the base or parent of the link
#
#   Returns true if a valid link
#
#   Calls the user function "test_url".  Link rewriting before spider
#   can be done here.
#
#------------------------------------------------------------------------------
sub check_link {
    my ( $u, $server, $base, $tag, $attribute ) = @_;

    $tag ||= '';
    $attribute ||= '';


    # Kill the fragment
    $u->fragment( undef );


    # Here we make sure we are looking at a link pointing to the correct (or equivalent) host

    unless ( $server->{scheme} eq $u->scheme && $server->{same_host_lookup}{$u->canonical->authority||''} ) {

        print STDERR qq[ ?? <$tag $attribute="$u"> skipped because different host\n] if $server->{debug} & DEBUG_LINKS;
        $server->{counts}{'Off-site links'}++;
        validate_link( $server, $u, $base ) if $server->{validate_links};
        return;
    }

    $u->host_port( $server->{authority} );  # Force all the same host name

    # Allow rejection of this URL by user function

    return unless check_user_function( 'test_url', $u, $server );


    # Don't add the link if already seen  - these are so common that we don't report
    # Might be better to do something like $visited{ $u->path } or $visited{$u->host_port}{$u->path};


    if ( $visited{ $u->canonical }++ ) {
        #$server->{counts}{Skipped}++;
        $server->{counts}{Duplicates}++;


        # Just so it's reported for all pages
        if ( $server->{validate_links} && $validated{$u->canonical} ) {
            push @{$bad_links{ $base->canonical }}, $u->canonical;
        }

        return;
    }

    return 1;
}


#=============================================================================
# This function is used to validate links that are off-site.
#
#   It's just a very basic link check routine that lets you validate the
#   off-site links at the same time as indexing.  Just because we can.
#
#------------------------------------------------------------------------------
sub validate_link {
    my ($server, $uri, $base, $response ) = @_;

    $base = URI->new( $base ) unless ref $base;
    $uri = URI->new_abs($uri, $base) unless ref $uri;


   # Already checked?

    if ( exists $validated{ $uri->canonical } )
    {
        # Add it to the list of bad links on that page if it's a bad link.
        push @{$bad_links{ $base->canonical }}, $uri->canonical
            if $validated{ $uri->canonical };

        return;
    }

    $validated{ $uri->canonical } = 0;  # mark as checked and ok.

    unless ( $response ) {
        my $ua = LWP::UserAgent->new(timeout =>  $server->{max_wait_time} );
        my $request = HTTP::Request->new('HEAD', $uri->canonical );
        $response = $ua->simple_request( $request );
    }

    return if $response->is_success;

    my $error = $response->status_line || $response->status || 'unknown status';

    $error .= ' ' . URI->new_abs( $response->header('location'), $response->base )->canonical
        if $response->is_redirect && $response->header('location');

    $validated{ $uri->canonical } = $error;
    push @{$bad_links{ $base->canonical }}, $uri->canonical;
}

#===================================================================================
# output_content -- formats content for swish-e
#
#-----------------------------------------------------------------------------------

sub output_content {
    my ( $server, $content, $uri, $response ) = @_;

    $server->{indexed}++;

    unless ( length $$content ) {
        print STDERR "Warning: document '", $response->request->uri, "' has no content\n";
        $$content = ' ';
    }


    ## Now, either need to re-encode into the original charset,
    # or remove any charset from <meta> tags and then return utf8.
    # HTTP::Message uses a different method to extract out the charset,
    # but should result in the same value.
    for ( $response->header('content-type') ){
        $server->{charset} = $1 if /\bcharset=([^;]+)/;
    }
    # Re-encode the data for outside of Perl
    eval {
        # Need to only require Encode here?
        $$content = Encode::encode( $server->{charset}, $$content )
            if $server->{charset};
    };
    if ( $@ ) {
        print STDERR "Warning: document '", $response->request->uri, "' could not be encoded to charset '$server->{charset}'\n";
        delete $server->{charset};
    }

    $server->{counts}{'Total Bytes'} += length $$content;
    $server->{counts}{'Total Docs'}++;


    # ugly and maybe expensive, but perhaps more portable than "use bytes"
    my $bytecount = length pack 'C0a*', $$content;

    # Decode the URL
    my $path = $uri;
    $path =~ s/%([0-9a-fA-F]{2})/chr hex($1)/ge;


    # For Josh
    if ( my $fn = $server->{output_function} ) {
        eval {
            $fn->(  $server, $content, $uri, $response, $bytecount, $path); 
        };
        die "output_function died for $uri: $@\n" if $@;

        die "$0: Max indexed files Reached\n"
            if $server->{max_indexed} && $server->{counts}{'Total Docs'} >= $server->{max_indexed};

        return;
    }


    my $headers = join "\n",
        'Path-Name: ' .  $path,
        'Content-Length: ' . $bytecount,
        '';


    $headers .= 'Charset: ' . delete( $server->{charset}) . "\n" if $server->{charset};

    $headers .= 'Last-Mtime: ' . $response->last_modified . "\n"
        if $response->last_modified;

    # Set the parser type if specified by filtering
    if ( my $type = delete $server->{parser_type} ) {
        $headers .= "Document-Type: $type\n";

    } elsif ( $response->content_type =~ m!^text/(html|xml|plain)! ) {
        $type = $1 eq 'plain' ? 'txt' : $1;
        $headers .= "Document-Type: $type*\n";
    }


    $headers .= "No-Contents: 1\n" if $server->{no_contents};
    print "$headers\n$$content";

    die "$0: Max indexed files Reached\n"
        if $server->{max_indexed} && $server->{counts}{'Total Docs'} >= $server->{max_indexed};
}



sub commify {
    local $_  = shift;
    1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
    return $_;
}

sub default_urls {

    my $validate = 0;
    if ( @ARGV && $ARGV[0] eq 'validate' ) {
        shift @ARGV;
        $validate = 1;
    }

    die "$0: Must list URLs when using 'default'\n" unless @ARGV;

    my $config = default_config();

    $config->{base_url} = [ @ARGV ];

    $config->{validate}++ if $validate;

    return $config;

}

# Returns a default config hash

sub default_config {

    ## See if we have any filters

    my ($filter_sub, $response_sub, $filter);

    eval { ($filter_sub, $response_sub, $filter) = swish_filter() };

    if ( $@ ) {

        warn "Failed to find the SWISH::Filter module.  Only processing text/* content.\n$@\n";

        $response_sub = sub {
            my $content_type = $_[2]->content_type;
            return $content_type =~ m!^text/!;
        }
    }

    return {
        email               => 'swish@user.failed.to.set.email.invalid',
        link_tags           => [qw/ a frame /],
        keep_alive          => 1,
        test_url            => sub {  $_[0]->path !~ /\.(?:gif|jpeg|png)$/i },
        test_response       => $response_sub,
        use_head_requests   => 1,  # Due to the response sub
        filter_content      => $filter_sub,
        filter_object       => $filter,
    };
}


#=================================================================================
# swish_filter
# returns a subroutine for filtering with SWISH::Filter -- for use in config files
#
#---------------------------------------------------------------------------------

sub swish_filter {


    require SWISH::Filter;

    my $filter = SWISH::Filter->new; # closure

    my $filter_sub = sub {
        my ( $uri, $server, $response, $content_ref ) = @_;

        my $content_type = $response->content_type;
        # Ignore text/* content type -- no need to filter
        if (  $content_type =~ m!^text/! ) {
            $server->{counts}{$content_type}++;
            return 1;
        }

        my $doc = $filter->convert(
            document     => $content_ref,
            name         => $response->base,
            content_type => $content_type,
        );

        return 1 unless $doc; # so just proceed as if not using filter

        if ( $doc->is_binary ) {  # ignore "binary" files (not text/* mime type)
            die "Skipping " . $response->base . " due to content type: " . $doc->content_type ." may be binary\n";
        }

        # nicer to use **char...
        $$content_ref = ${$doc->fetch_doc};

        # let's see if we can set the parser.
        $server->{parser_type} = $doc->swish_parser_type || '';

        $server->{counts}{"$content_type->" . $doc->content_type}++;

        return 1;
    };

    # This is used in HEAD request to test the content type ahead of time
    my $response_sub = sub {
        my ( $uri, $server, $response, $content_ref ) = @_;
        my $content_type = $response->content_type;
        return 1 if $content_type =~ m!^text/!;  # allow all text (assume don't want to filter)
        return $filter->can_filter( $content_type );
    };


    return ( $filter_sub, $response_sub, $filter );
}

__END__

=head1 NAME

spider.pl - Example Perl program to spider web servers

=head1 SYNOPSIS

    spider.pl [<spider config file>] [<URL> ...]

    # Spider using some common defaults and capture the output
    # into a file

    ./spider.pl default http://myserver.com/ > output.txt


    # or using a config file

    spider.config:
    @servers = (
        {
            base_url    => 'http://myserver.com/',
            email       => 'me@myself.com',
            # other spider settings described below
        },
    );

    ./spider.pl spider.config > output.txt


    # or using the default config file SwishSpiderConfig.pl
    ./spider.pl > output.txt

    # using with swish-e

    ./spider.pl spider.config | swish-e -c swish.config -S prog -i stdin

    # or in two steps
    ./spider.pl spider.config > output.txt
    swish-e -c swish.config -S prog -i stdin < output.txt

    # or with compression
    ./spider.pl spider.config | gzip > output.gz
    gzip -dc output.gz | swish-e -c swish.config -S prog -i stdin

    # or having swish-e call the spider directly using the
    # spider config file SwishSpiderConfig.pl:
    swish-e -c swish.config -S prog -i spider.pl


    # or the above but passing passing a parameter to the spider:
    echo "SwishProgParameters  spider.config" >> swish.config
    echo "IndexDir spider.pl" >> swish.config
    swish-e -c swish.config -S prog


    Note: When running on some versions of Windows (e.g. Win ME and Win 98 SE)
    you may need to tell Perl to run the spider directly:

        perl spider.pl | swish-e -S prog -c swish.conf -i stdin

    This pipes the output of the spider directly into swish.


=head1 DESCRIPTION

F<spider.pl> is a program for fetching documnts from a web server,
and outputs the documents to STDOUT in a special format designed
to be read by Swish-e.

The spider can index non-text documents such as PDF and MS Word by use of
filter (helper) programs.  These programs are not part of the Swish-e
distribution and must be installed separately.  See the section on filtering
below.

A configuration file is noramlly used to control what documents are fetched
from the web server(s).  The configuration file and its options are described
below.  The is also a "default" config suitable for spidering.

The spider is designed to spider web pages and fetch documents from one
host at a time -- offsite links are not followed.  But, you can configure
the spider to spider multiple sites in a single run.

F<spider.pl> is distributed with Swish-e and is installed in the swish-e
library directory at installation time.  This directory (libexedir) can
be seen by running the command:

    swish-e -h

Typically on unix-type systems the spider is installed at:

    /usr/local/lib/swish-e/spider.pl

This spider stores all links in memory while processing and does not do
parallel requests.

=head2 Running the spider

The output from F<spider.pl> can be captured to a temporary file which is then
fed into swish-e:

    ./spider.pl > docs.txt
    swish-e -c config -S prog -i stdin < docs.txt

or the output can be passed to swish-e via a pipe:

   ./spider.pl | swish-e -c config -S prog -i stdin

or the swish-e can run the spider directly:

   swish-e -c config -S prog -i spider.pl

One advantage of having Swish-e run F<spider.pl> is that Swish-e knows
where to locate the program (based on libexecdir compiled into swish-e).

When running the spider I<without> any parameters it looks for a configuration file
called F<SwishSpiderConfig.pl> in the current directory.  The spider will abort
with an error if this file is not found.

A configuration file can be specified as the first parameter to the spider:

    ./spider.pl spider.config > output.txt

If running the spider via Swish-e (i.e. Swish-e runs the spider) then use
the Swish-e config option L<SwishProgParameters|SWISH-CONFIG/"item_SwishProgParameters">
to specify the config file:

In swish.config:

    # Use spider.pl as the external program:
    IndexDir spider.pl
    # And pass the name of the spider config file to the spider:
    SwishProgParameters spider.config

And then run Swish-e like this:

    swish-e -c swish.config -S prog

Finally, by using the special word "default" on the command line the spider will
use a default configuration that is useful for indexing most sites.  It's a good
way to get started with the spider:

    ./spider.pl default http://my_server.com/index.html > output.txt

There's no "best" way to run the spider.  I like to capture to a file
and then feed that into Swish-e.

The spider does require Perl's LWP library and a few other reasonably common
modules.  Most well maintained systems should have these modules installed.
See  L</"REQUIREMENTS"> below for more information.  It's a good idea to check
that you are running a current version of these modules.

Note: the "prog" document source in Swish-e bypasses many Swish-e configuration
settings.  For example, you cannot use the
L<IndexOnly|SWISH-CONFIG/"item_SwishProgParameters"> directive with the "prog"
document source.  This is by design to limit the overhead when using an
external program for providing documents to swish; after all, with "prog", if
you don't want to index a file, then don't give it to swish to index in the
first place.

So, for spidering, if you do not wish to index images, for example, you will
need to either filter by the URL or by the content-type returned from the web
server.  See L</"CALLBACK FUNCTIONS"> below for more information.


=head2 Robots Exclusion Rules and being nice

By default, this script will not spider files blocked by F<robots.txt>.  In addition,
The script will check for E<lt>meta name="robots"..E<gt> tags, which allows finer
control over what files are indexed and/or spidered.
See http://www.robotstxt.org/wc/exclusion.html for details.

This spider provides an extension to the E<lt>metaE<gt> tag exclusion, by adding a
B<NOCONTENTS> attribute.  This attribute turns on the C<no_contents> setting, which
asks swish-e to only index the document's title (or file name if not title is found).

For example:

      <META NAME="ROBOTS" CONTENT="NOCONTENTS, NOFOLLOW">

says to just index the document's title, but don't index its contents, and don't follow
any links within the document.  Granted, it's unlikely that this feature will ever be used...

If you are indexing your own site, and know what you are doing, you can disable robot
exclusion by the C<ignore_robots_file> configuration parameter, described below.  This
disables both F<robots.txt> and the meta tag parsing.  You may disable just the meta tag
parsing by using C<ignore_robots_headers>.

This script only spiders one file at a time, so load on the web server is not that great.
And with libwww-perl-5.53_91 HTTP/1.1 keep alive requests can reduce the load on
the server even more (and potentially reduce spidering time considerably).

Still, discuss spidering with a site's administrator before beginning.
Use the C<delay_sec> to adjust how fast the spider fetches documents.
Consider running a second web server with a limited number of children if you really
want to fine tune the resources used by spidering.

=head2 Duplicate Documents

The spider program keeps track of URLs visited, so a document is only indexed
one time.

The Digest::MD5 module can be used to create a "fingerprint" of every page
indexed and this fingerprint is used in a hash to find duplicate pages.
For example, MD5 will prevent indexing these as two different documents:

    http://localhost/path/to/some/index.html
    http://localhost/path/to/some/

But note that this may have side effects you don't want.  If you want this
file indexed under this URL:

    http://localhost/important.html

But the spider happens to find the exact content in this file first:

    http://localhost/developement/test/todo/maybeimportant.html

Then only that URL will be indexed.

=head2 Broken relative links

Sometimes web page authors use too many C</../> segments in relative URLs which reference
documents above the document root.  Some web servers such as Apache will return a
400 Bad Request when requesting a document above the root.  Other web servers such as
Micorsoft IIS/5.0 will try and "correct" these errors.  This correction will lead to
loops when spidering.

The spider can fix these above-root links by placing the following in your spider config:

    remove_leading_dots => 1,

It is not on by default so that the spider can report the broken links (as 400 errors on
sane webservers).

=head2 Compression


If The Perl module Compress::Zlib is installed the spider will send the

   Accept-Encoding: gzip x-gzip

header and uncompress the document if the server returns the header

   Content-Encoding: gzip
   Content-Encoding: x-gzip

If The Perl distribution IO-Compress-Zlib is installed the spider will use
this module to uncompress "gzip" (x-gzip) and also "deflate" compressed
documents.

The "compress" method is not supported.

See RFC 2616 section 3.5 for more information.

MD5 checksomes are done on the compressed data.

MD5 may slow down indexing a tiny bit, so test with and without if speed is an
issue (which it probably isn't since you are spidering in the first place).
This feature will also use more memory.

=head1 REQUIREMENTS

Perl 5 (hopefully at least 5.00503) or later.

You must have the LWP Bundle on your computer.  Load the LWP::Bundle via the CPAN.pm shell,
or download libwww-perl-x.xx from CPAN (or via ActiveState's ppm utility).
Also required is the the HTML-Parser-x.xx bundle of modules also from CPAN
(and from ActiveState for Windows).

    http://search.cpan.org/search?dist=libwww-perl
    http://search.cpan.org/search?dist=HTML-Parser

You will also need Digest::MD5 if you wish to use the MD5 feature.
HTML::Tagset is also required.
Other modules may be required (for example, the pod2xml.pm module
has its own requirementes -- see perldoc pod2xml for info).

The spider.pl script, like everyone else, expects perl to live in /usr/local/bin.
If this is not the case then either add a symlink at /usr/local/bin/perl
to point to where perl is installed
or modify the shebang (#!) line at the top of the spider.pl program.

Note that the libwww-perl package does not support SSL (Secure Sockets Layer) (https)
by default.  See F<README.SSL> included in the libwww-perl package for information on
installing SSL support.

=head1 CONFIGURATION FILE

The spider configuration file is a read by the script as Perl code.
This makes the configuration a bit more complex than simple text config
files, but allows the spider to be configured programmatically.

For example, the config file can contain logic for testing URLs against regular
expressions or even against a database lookup while running.

The configuration file sets an array called C<@servers>.  This array can contain
one or more hash structures of parameters.  Each hash structure is a configuration for
a single server.

Here's an example:

    my %main_site = (
        base_url   => 'http://example.com',
        same_hosts => 'www.example.com',
        email      => 'admin@example.com',
    );

    my %news_site = (
        base_url   => 'http://news.example.com',
        email      => 'admin@example.com',
    );

    @servers = ( \%main_site, \%news_site );
    1;

The above defines two Perl hashes (%main_site and %news_site) and then places
a *reference* (the backslash before the name of the hash) to each of those
hashes in the @servers array.  The "1;" at the end is required at the end
of the file (Perl must see a true value at the end of the file).

The C<config file path> is the first parameter passed to the spider script.

    ./spider.pl F<config>

If you do not specify a config file then the spider will look for the file
F<SwishSpiderConfig.pl> in the current directory.

The Swish-e distribution includes a F<SwishSpiderConfig.pl> file with a few
example configurations.  This example file is installed in the F<prog-bin/>
documentation directory (on unix often this is
/usr/local/share/swish-e/prog-bin).

When the special config file name "default" is used:

    SwishProgParameters default http://www.mysite/index.html [<URL>] [...]

Then a default set of parameters are used with the spider.  This is a good way to start
using the spider before attempting to create a configuration file.

The default settings skip any urls that look like images (well, .gif .jpeg
.png), and attempts to filter PDF and MS Word documents IF you have the
required filter programs installed (which are not part of the Swish-e
distribution).  The spider will follow "a" and "frame" type of links only.

Note that if you do use a spider configuration file that the default configuration will NOT
be used (unless you set the "use_default_config" option in your config file).


=head1 CONFIGURATION OPTIONS

This describes the required and optional keys in the server configuration hash, in random order...

=over 4

=item base_url

This required setting is the starting URL for spidering.

This sets the first URL the spider will fetch.  It does NOT limit spidering
to URLs at or below the level of the directory specified in this setting.
For that feature you need to use the C<test_url> callback function.

Typically, you will just list one URL for the base_url.  You may specify more
than one URL as a reference to a list and each will be spidered:

    base_url => [qw! http://swish-e.org/ http://othersite.org/other/index.html !],

but each site will use the same config opions.  If you want to index two separate
sites you will likely rather add an additional configuration to the
@servers array.

You may specify a username and password:

    base_url => 'http://user:pass@swish-e.org/index.html',

If a URL is protected by Basic Authentication you will be prompted for a
username and password.  The parameter C<max_wait_time> controls how long to
wait for user entry before skipping the current URL.  See also C<credentials>
below.


=item same_hosts

This optional key sets equivalent B<authority> name(s) for the site you are spidering.
For example, if your site is C<www.mysite.edu> but also can be reached by
C<mysite.edu> (with or without C<www>) and also C<web.mysite.edu> then:


Example:

    $serverA{base_url} = 'http://www.mysite.edu/index.html';
    $serverA{same_hosts} = ['mysite.edu', 'web.mysite.edu'];

Now, if a link is found while spidering of:

    http://web.mysite.edu/path/to/file.html

it will be considered on the same site, and will actually spidered and indexed
as:

    http://www.mysite.edu/path/to/file.html

Note: This should probably be called B<same_host_port> because it compares the URI C<host:port>
against the list of host names in C<same_hosts>.  So, if you specify a port name in you will
want to specify the port name in the the list of hosts in C<same_hosts>:

    my %serverA = (
        base_url    => 'http://sunsite.berkeley.edu:4444/',
        same_hosts  => [ qw/www.sunsite.berkeley.edu:4444/ ],
        email       => 'my@email.address',
    );


=item email

This required key sets the email address for the spider.  Set this to
your email address.

=item agent

This optional key sets the name of the spider.

=item link_tags

This optional tag is a reference to an array of tags.  Only links found in these tags will be extracted.
The default is to only extract links from E<gt>aE<lt> tags.

For example, to extract tags from C<a> tags and from C<frame> tags:

    my %serverA = (
        base_url    => 'http://sunsite.berkeley.edu:4444/',
        same_hosts  => [ qw/www.sunsite.berkeley.edu:4444/ ],
        email       => 'my@email.address',
        link_tags   => [qw/ a frame /],
    );

=item use_default_config

This option is new for Swish-e 2.4.3.

The spider has a hard-coded default configuration that's available when the spider
is run with the configuration file listed as "default":

    ./spider.pl default <url>

This default configuration skips urls that match the regular expression:

    /\.(?:gif|jpeg|png)$/i

and the spider will attempt to use the SWISH::Filter module for filtering non-text
documents.  (You still need to install programs to do the actual filtering, though).

Here's the basic config for the "default" mode:

    @servers = (
    {
        email               => 'swish@user.failed.to.set.email.invalid',
        link_tags           => [qw/ a frame /],
        keep_alive          => 1,
        test_url            => sub {  $_[0]->path !~ /\.(?:gif|jpeg|png)$/i },
        test_response       => $response_sub,
        use_head_requests   => 1,  # Due to the response sub
        filter_content      => $filter_sub,
    } );

The filter_content callback will be used if SWISH::Filter was loaded and ready to use.
This doesn't mean that filtering will work automatically -- you will likely need to install
aditional programs for filtering (like Xpdf or Catdoc).

The test_response callback will be set to test if a given content type can be filtered
by SWISH::Filter (if SWISH::Filter was loaded), otherwise, it will check for 
content-type of text/* -- any text type of document.


Normally, if you specify your own config file:

    ./spider.pl my_own_spider.config

then you must setup those features available in the default setting in your own config
file.  But, if you wish to build upon the "default" config file then set this option.

For example, to use the default config but specify your own email address:

    @servers = (
        {
            email               => my@email.address,
            use_default_config  => 1,
            delay_sec           => 0,
        },
    );
    1;

What this does is "merge" your config file with the default config file.

=item delay_sec

This optional key sets the delay in seconds to wait between requests.  See the
LWP::RobotUA man page for more information.  The default is 5 seconds.
Set to zero for no delay.

When using the keep_alive feature (recommended) the delay will be used only
where the previous request returned a "Connection: closed" header.


=item delay_min  (deprecated)

Set the delay to wait between requests in minutes.  If both delay_sec and
delay_min are defined, delay_sec will be used.


=item max_wait_time

This setting is the number of seconds to wait for data to be returned from
the request.  Data is returned in chunks to the spider, and the timer is
reset each time a new chunk is reported.  Therefore, documents (requests)
that take longer than this setting should not be aborted as long as some
data is received every max_wait_time seconds. The default it 30 seconds.

NOTE: This option has no effect on Windows.

=item max_time

This optional key will set the max minutes to spider.   Spidering
for this host will stop after C<max_time> minutes, and move on to the
next server, if any.  The default is to not limit by time.

=item max_files

This optional key sets the max number of files to spider before aborting.
The default is to not limit by number of files.  This is the number of requests
made to the remote server, not the total number of files to index (see C<max_indexed>).
This count is displayted at the end of indexing as C<Unique URLs>.

This feature can (and perhaps should) be use when spidering a web site where dynamic
content may generate unique URLs to prevent run-away spidering.

=item max_indexed

This optional key sets the max number of files that will be indexed.
The default is to not limit.  This is the number of files sent to
swish for indexing (and is reported by C<Total Docs> when spidering ends).

=item max_size

This optional key sets the max size of a file read from the web server.
This B<defaults> to 5,000,000 bytes.  If the size is exceeded the resource is
skipped and a message is written to STDERR if the DEBUG_SKIPPED debug flag is set.

Set max_size to zero for unlimited size.  If the server returns a Content-Length
header then that will be used.  Otherwise, the document will be checked for
size limitation as it arrives.  That's a good reason to have your server send
Content-Length headers.

See also C<use_head_requests> below.

=item keep_alive

This optional parameter will enable keep alive requests.  This can dramatically speed
up spidering and reduce the load on server being spidered.  The default is to not use
keep alives, although enabling it will probably be the right thing to do.

To get the most out of keep alives, you may want to set up your web server to
allow a lot of requests per single connection (i.e MaxKeepAliveRequests on Apache).
Apache's default is 100, which should be good.

When a connection is not closed the spider does not wait the "delay_sec"
time when making the next request.  In other words, there is no delay in
requesting documents while the connection is open.

Note: try to filter as many documents as possible B<before> making the request to the server.  In
other words, use C<test_url> to look for files ending in C<.html> instead of using C<test_response> to look
for a content type of C<text/html> if possible.
Do note that aborting a request from C<test_response> will break the
current keep alive connection.

Note: you must have at least libwww-perl-5.53_90 installed to use this feature.

=item use_head_requests

This option is new as of swish-e 2.4.3 and can effect the speed of spidering and the
load of the web server.

To understand this you will likely need to read about the L</"CALLBACK FUNCTIONS">
below -- specifically about the C<test_response> callback function.  This option is
also only used when C<keep_alive> is also enabled (although it could be debated that
it's useful without keep alives).

This option tells the spider to use http HEAD requests before each request.

Normally, the spider simply does a GET request and after receiving the first
chunk of data back from the web server calls the C<test_response> callback
function (if one is defined in your config file).  The C<test_response>
callback function is a good place to test the content-type header returned from
the server and reject types that you do not want to index.

Now, *if* you are using the C<keep_alive> feature then rejecting a document 
will often (always?) break the keep alive connection.

So, what the C<use_head_requests> option does is issue a HEAD request for every
document, checks for a Content-Length header (to check if the document is larger than
C<max_size>, and then calls your C<test_response> callback function.  If your callback
function returns true then a GET request is used to fetch the document.

The idea is that by using HEAD requests instead of GET request a false return from 
your C<test_response> callback function (i.e. rejecting the document) will not
break the keep alive connection.

Now, don't get too excited about this.  Before using this think about the ratio of
rejected documents to accepted documents.  If you reject no documents then using this feature
will double the number of requests to the web server -- which will also double the number of
connections to the web server.  But, if you reject a large percentage of documents then
this feature will help maximize the number of keep alive requests to the server (i.e.
reduce the number of separate connections needed).

There's also another problem with using HEAD requests.  Some broken servers
may not respond correctly to HEAD requests (some issues a 500 error), but respond
fine to a normal GET request.  This is something to watch out for.

Finally, if you do not have a C<test_response> callback AND C<max_size> is set to zero
then setting C<use_head_requests> will have no effect.

And, with all other factors involved you might find this option has no effect at all.


=item skip

This optional key can be used to skip the current server.  It's only purpose
is to make it easy to disable a specific server hash in a configuration file.

=item debug

Set this item to a comma-separated list of debugging options.

Options are currently:

    errors, failed, headers, info, links, redirect, skipped, url

Here are basically the levels:

    errors      =>   general program errors (not used at this time)
    url         =>   print out every URL processes
    headers     =>   prints the response headers
    failed      =>   failed to return a 200
    skipped     =>   didn't index for some reason
    info        =>   a little more verbose
    links       =>   prints links as they are extracted
    redirect    =>   prints out redirected URLs

Debugging can be also be set by an environment variable SPIDER_DEBUG when running F<spider.pl>.
You can specify any of the above debugging options, separated by a comma.

For example with Bourne type shell:

    SPIDER_DEBUG=url,links spider.pl [....]

Before Swish-e 2.4.3 you had to use the internal debugging constants or'ed together
like so:

    debug => DEBUG_URL | DEBUG_FAILED | DEBUG_SKIPPED,

You can still do this, but the string version is easier.  In fact, if you want
to turn on debugging dynamically (for example in a test_url() callback
function) then you currently *must* use the DEBUG_* constants.  The string is
converted to a number only at the start of spiderig -- after that the C<debug>
parameter is converted to a number.


=item quiet

If this is true then normal, non-error messages will be supressed.  Quiet mode can also
be set by setting the environment variable SPIDER_QUIET to any true value.

    SPIDER_QUIET=1

=item max_depth

The C<max_depth> parameter can be used to limit how deeply to recurse a web site.
The depth is just a count of levels of web pages descended, and not related to
the number of path elements in a URL.

A max_depth of zero says to only spider the page listed as the C<base_url>.  A max_depth of one will
spider the C<base_url> page, plus all links on that page, and no more.  The default is to spider all
pages.


=item ignore_robots_file

If this is set to true then the robots.txt file will not be checked when spidering
this server.  Don't use this option unless you know what you are doing.

=item use_cookies

If this is set then a "cookie jar" will be maintained while spidering.  Some
(poorly written ;) sites require cookies to be enabled on clients.

This requires the HTTP::Cookies module.

=item use_md5

If this setting is true, then a MD5 digest "fingerprint" will be made from the content of every
spidered document.  This digest number will be used as a hash key to prevent
indexing the same content more than once.  This is helpful if different URLs
generate the same content.

Obvious example is these two documents will only be indexed one time:

    http://localhost/path/to/index.html
    http://localhost/path/to/

This option requires the Digest::MD5 module.  Spidering with this option might
be a tiny bit slower.

=item validate_links

Just a hack.  If you set this true the spider will do HEAD requests all links (e.g. off-site links), just
to make sure that all your links work.

=item credentials

You may specify a username and password to be used automatically when spidering:

    credentials => 'username:password',

A username and password supplied in a URL will override this setting.
This username and password will be used for every request.

See also the C<get_password> callback function below.  C<get_password>, if defined,
will be called when a page requires authorization.

=item credential_timeout

Sets the number of seconds to wait for user input when prompted for a username or password.
The default is 30 seconds.

Set this to zero to wait forever.  Probably not a good idea.

Set to undef to disable asking for a password.

    credential_timeout => undef,


=item remove_leading_dots

Removes leading dots from URLs that might reference documents above the document root.
The default is to not remove the dots.

=back

=head1 CALLBACK FUNCTIONS

Callback functions can be defined in your parameter hash.
These optional settings are I<callback> subroutines that are called while
processing URLs.

A little perl discussion is in order:

In perl, a scalar variable can contain a reference to a subroutine.  The config example above shows
that the configuration parameters are stored in a perl I<hash>.

    my %serverA = (
        base_url    => 'http://sunsite.berkeley.edu:4444/',
        same_hosts  => [ qw/www.sunsite.berkeley.edu:4444/ ],
        email       => 'my@email.address',
        link_tags   => [qw/ a frame /],
    );

There's two ways to add a reference to a subroutine to this hash:

sub foo {
    return 1;
}

    my %serverA = (
        base_url    => 'http://sunsite.berkeley.edu:4444/',
        same_hosts  => [ qw/www.sunsite.berkeley.edu:4444/ ],
        email       => 'my@email.address',
        link_tags   => [qw/ a frame /],
        test_url    => \&foo,  # a reference to a named subroutine
    );

Or the subroutine can be coded right in place:

    my %serverA = (
        base_url    => 'http://sunsite.berkeley.edu:4444/',
        same_hosts  => [ qw/www.sunsite.berkeley.edu:4444/ ],
        email       => 'my@email.address',
        link_tags   => [qw/ a frame /],
        test_url    => sub { reutrn 1; },
    );

The above example is not very useful as it just creates a user callback function that
always returns a true value (the number 1).  But, it's just an example.

The function calls are wrapped in an eval, so calling die (or doing something that dies) will just cause
that URL to be skipped.  If you really want to stop processing you need to set $server-E<gt>{abort} in your
subroutine (or send a kill -HUP to the spider).

The first two parameters passed are a URI object (to have access to the current URL), and
a reference to the current server hash.  The C<server> hash is just a global hash for holding data, and
useful for setting flags as described below.

Other parameters may be also passed in depending the the callback function,
as described below. In perl parameters are passed in an array called "@_".
The first element (first parameter) of that array is $_[0], and the second
is $_[1], and so on.  Depending on how complicated your function is you may
wish to shift your parameters off of the @_ list to make working with them
easier.  See the examples below.


To make use of these routines you need to understand when they are called, and what changes
you can make in your routines.  Each routine deals with a given step, and returning false from
your routine will stop processing for the current URL.

=over 4

=item test_url

C<test_url> allows you to skip processing of urls based on the url before the request
to the server is made.  This function is called for the C<base_url> links (links you define in
the spider configuration file) and for every link extracted from a fetched web page.

This function is a good place to skip links that you are not interested in following.  For example,
if you know there's no point in requesting images then you can exclude them like:

    test_url => sub {
        my $uri = shift;
        return 0 if $uri->path =~ /\.(gif|jpeg|png)$/;
        return 1;
    },

Or to write it another way:

    test_url => sub { $_[0]->path !~ /\.(gif|jpeg|png)$/ },

Another feature would be if you were using a web server where path names are
NOT case sensitive (e.g. Windows).  You can normalize all links in this situation
using something like

    test_url => sub {
        my $uri = shift;
        return 0 if $uri->path =~ /\.(gif|jpeg|png)$/;

        $uri->path( lc $uri->path ); # make all path names lowercase
        return 1;
    },

The important thing about C<test_url> (compared to the other callback functions) is that
it is called while I<extracting> links, not while actually fetching that page from the web
server.  Returning false from C<test_url> simple says to not add the URL to the list of links to
spider.

You may set a flag in the server hash (second parameter) to tell the spider to abort processing.

    test_url => sub {
        my $server = $_[1];
        $server->{abort}++ if $_[0]->path =~ /foo\.html/;
        return 1;
    },

You cannot use the server flags:

    no_contents
    no_index
    no_spider


This is discussed below.

=item test_response

This function allows you to filter based on the response from the remote server
(such as by content-type).

Web servers use a Content-Type: header to define the type of data returned from the server.
On a web server you could have a .jpeg file be a web page -- file extensions may not always
indicate the type of the file.

If you enable C<use_head_requests> then this function is called after the
spider makes a HEAD request.  Otherwise, this function is called while the web
pages is being fetched from the remote server, typically after just enought
data has been returned to read the response from the web server.

The test_response callback function is called with the following parameters:

    ( $uri, $server, $response, $content_chunk )

The $response variable is a HTTP::Response object and provies methods of examining
the server's response.  The $content_chunk is the first chunk of data returned from
the server (if not a HEAD request).

When not using C<use_head_requests> the spider requests a document in "chunks"
of 4096 bytes.  4096 is only a suggestion of how many bytes to return in each
chunk.  The C<test_response> routine is called when the first chunk is received
only.  This allows ignoring (aborting) reading of a very large file, for
example, without having to read the entire file.  Although not much use, a
reference to this chunk is passed as the forth parameter.

If you are spidering a site with many different types of content that you do
not wish to index (and cannot use a test_url callback to determine what docs to skip)
then you will see better performance using both the C<use_head_requests> and C<keep_alive>
features.  (Aborting a GET request kills the keep-alive session.)

For example, to only index true HTML (text/html) pages:

    test_response => sub {
        my $content_type = $_[2]->content_type;
        return $content_type =~ m!text/html!;
    },

You can also set flags in the server hash (the second parameter) to control indexing:

    no_contents -- index only the title (or file name), and not the contents
    no_index    -- do not index this file, but continue to spider if HTML
    no_spider   -- index, but do not spider this file for links to follow
    abort       -- stop spidering any more files

For example, to avoid index the contents of "private.html", yet still follow any links
in that file:

    test_response => sub {
        my $server = $_[1];
        $server->{no_index}++ if $_[0]->path =~ /private\.html$/;
        return 1;
    },

Note: Do not modify the URI object in this call back function.


=item filter_content

This callback function is called right before sending the content to swish.
Like the other callback function, returning false will cause the URL to be skipped.
Setting the C<abort> server flag and returning false will abort spidering.

You can also set the C<no_contents> flag.

This callback function is passed four parameters.
The URI object, server hash, the HTTP::Response object,
and a reference to the content.

You can modify the content as needed.  For example you might not like upper case:

    filter_content => sub {
        my $content_ref = $_[3];

        $$content_ref = lc $$content_ref;
        return 1;
    },

I more reasonable example would be converting PDF or MS Word documents for
parsing by swish. Examples of this are provided in the F<prog-bin> directory
of the swish-e distribution.

You may also modify the URI object to change the path name passed to swish for indexing.

    filter_content => sub {
        my $uri = $_[0];
        $uri->host('www.other.host') ;
        return 1;
    },

Swish-e's ReplaceRules feature can also be used for modifying the path name indexed.

Note: Swish-e now includes a method of filtering based on the SWISH::Filter
Perl modules.  See the SwishSpiderConfig.pl file for an example how to use
SWISH::Filter in a filter_content callback function.

If you use the "default" configuration (i.e. pass "default" as the first parameter
to the spider) then SWISH::Filter is used automatically.  This only adds code for
calling the programs to filter your content -- you still need to install applications
that do the hard work (like xpdf for pdf conversion and catdoc for MS Word conversion).


The a function included in the F<spider.pl> for calling SWISH::Filter when using the "default"
config can also be used in your config file.  There's a function called 
swish_filter() that returns a list of two subroutines.  So in your config you could
do:

    my ($filter_sub, $response_sub ) = swish_filter();

    @server = ( {
        test_response   => $response_sub,
        filter_content  => $filter_sub,
        [...],
    } );

The $response_sub is not required, but is useful if using HEAD requests (C<use_head_requests>):
It tests the content type from the server to see if there's any filters that can handle
the document.  The $filter_sub does all the work of filtering a document.

Make sense?  If not, then that's what the Swish-e list is for.


=item spider_done

This callback is called after processing a server (after each server listed
in the @servers array if more than one).

This allows your config file to do any cleanup work after processing.
For example, if you were keeping counts during, say, a test_response() callback
function you could use the spider_done() callback to print the results.


=item output_function

If defined, this callback function is called instead of printing the content
and header to STDOUT.  This can be used if you want to store the output of the
spider before indexing.

The output_function is called with the following parameters:

   ($server, $content, $uri, $response, $bytecount, $path);

Here is an example that simply shows two of the params passed:

    output_function => sub {
        my ($server, $content, $uri, $response, $bytecount, $path) = @_;
        print STDERR  "passed: uri $uri, bytecount $bytecount...\n";
        # no output to STDOUT for swish-e
    }

You can do almost the same thing with a filter_content callback.


=item get_password

This callback is called when a HTTP password is needed (i.e. after the server
returns a 401 error).  The function can test the URI and Realm and then return
a username and password separated by a colon:

    get_password => sub {
        my ( $uri, $server, $response, $realm ) = @_;
        if ( $uri->path =~ m!^/path/to/protected! && $realm eq 'private' ) {
            return 'joe:secret931password';
        }
        return;  # sorry, I don't know the password.
    },

Use the C<credentials> setting if you know the username and password and they will
be the same for every request.  That is, for a site-wide password.


=back

Note that you can create your own counters to display in the summary list when spidering
is finished by adding a value to the hash pointed to by C<$server-E<gt>{counts}>.

    test_url => sub {
        my $server = $_[1];
        $server->{no_index}++ if $_[0]->path =~ /private\.html$/;
        $server->{counts}{'Private Files'}++;
        return 1;
    },


Each callback function B<must> return true to continue processing the URL.  Returning false will
cause processing of I<the current> URL to be skipped.

=head2 More on setting flags

Swish (not this spider) has a configuration directive C<NoContents> that will instruct swish to
index only the title (or file name), and not the contents.  This is often used when
indexing binary files such as image files, but can also be used with html
files to index only the document titles.

As shown above, you can turn this feature on for specific documents by setting a flag in
the server hash passed into the C<test_response> or C<filter_content> subroutines.
For example, in your configuration file you might have the C<test_response> callback set
as:

    test_response => sub {
        my ( $uri, $server, $response ) = @_;
        # tell swish not to index the contents if this is of type image
        $server->{no_contents} = $response->content_type =~ m[^image/];
        return 1;  # ok to index and spider this document
    }

The entire contents of the resource is still read from the web server, and passed
on to swish, but swish will also be passed a C<No-Contents> header which tells
swish to enable the NoContents feature for this document only.

Note: Swish will index the path name only when C<NoContents> is set, unless the document's
type (as set by the swish configuration settings C<IndexContents> or C<DefaultContents>) is
HTML I<and> a title is found in the html document.

Note: In most cases you probably would not want to send a large binary file to swish, just
to be ignored.  Therefore, it would be smart to use a C<filter_content> callback routine to
replace the contents with single character (you cannot use the empty string at this time).

A similar flag may be set to prevent indexing a document at all, but still allow spidering.
In general, if you want completely skip spidering a file you return false from one of the
callback routines (C<test_url>, C<test_response>, or C<filter_content>).  Returning false from any of those
three callbacks will stop processing of that file, and the file will B<not> be spidered.

But there may be some cases where you still want to spider (extract links) yet, not index the file.  An example
might be where you wish to index only PDF files, but you still need to spider all HTML files to find
the links to the PDF files.

    $server{test_response} = sub {
        my ( $uri, $server, $response ) = @_;
        $server->{no_index} = $response->content_type ne 'application/pdf';
        return 1;  # ok to spider, but don't index
    }

So, the difference between C<no_contents> and C<no_index> is that C<no_contents> will still index the file
name, just not the contents.  C<no_index> will still spider the file (if it's C<text/html>) but the
file will not be processed by swish at all.

B<Note:> If C<no_index> is set in a C<test_response> callback function then
the document I<will not be filtered>.  That is, your C<filter_content>
callback function will not be called.

The C<no_spider> flag can be set to avoid spiderering an HTML file.  The file will still be indexed unless
C<no_index> is also set.  But if you do not want to index and spider, then simply return false from one of the three
callback funtions.


=head1 SIGNALS

Sending a SIGHUP to the running spider will cause it to stop spidering.  This is a good way to abort spidering, but
let swish index the documents retrieved so far.

=head1 CHANGES

List of some of the changes

=head2 Thu Sep 30 2004 - changes for Swish-e 2.4.3


Code reorganization and a few new featues.  Updated docs a little tiny bit.
Introduced a few spelling mistakes.

=over 4

=item Config opiton: use_default_config

It used to be that you could run the spider like:

    spider.pl default <some url>

and the spider would use its own internal config.  But if you used your own
config file then the defaults were not used.  This options allows you to merge
your config with the default config.  Makes making small changes to the default
easy.

=item Config option: use_head_requests

Tells the spider to make a HEAD request before GET'ing the document from the web server.
Useful if you use keep_alive and have a test_response() callback that rejects many documents
(which breaks the connection).

=item Config option: spider_done

Callback to tell you (or tell your config as it may be) that the spider is done.
Useful if you need to do some extra processing when done spidering -- like record
counts to a file.

=item Config option: get_password

This callback is called when a document returns a 401 error needing a username 
and password.  Useful if spidering a site proteced with multiple passwords.

=item Config option: output_function

If defined spider.pl calls this instead of sending ouptut to STDOUT.

=item Config option: debug

Now you can use the words instead of or'ing the DEBUG_* constants together.

=back

=head1 TODO

Add a "get_document" callback that is called right before making the "GET" request.
This would make it easier to use cached documents.  You can do that now in a test_url
callback or in a test_response when using HEAD request.

Save state of the spider on SIGHUP so spidering could be restored at a later date.



=head1 COPYRIGHT

Copyright 2001 Bill Moseley

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SUPPORT

Send all questions to the The SWISH-E discussion list.

See http://sunsite.berkeley.edu/SWISH-E.

=cut

