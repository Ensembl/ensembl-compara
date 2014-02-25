=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Apache::Handlers;

use strict;

use Apache2::Const qw(:common :http :methods);
use Apache2::SizeLimit;
use Apache2::Connection;
use Apache2::URI;
use APR::URI;
use Config;
use Fcntl ':flock';
use Sys::Hostname;
use Time::HiRes qw(time);
use URI::Escape qw(uri_escape);

use SiteDefs;# qw(:APACHE);

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Registry;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::SpeciesDefs;

use EnsEMBL::Web::Apache::DasHandler;
use EnsEMBL::Web::Apache::SSI;
use EnsEMBL::Web::Apache::SpeciesHandler;

our $species_defs = EnsEMBL::Web::SpeciesDefs->new;
our $MEMD         = EnsEMBL::Web::Cache->new;

our $BLAST_LAST_RUN;
our $LOAD_COMMAND;

BEGIN {
  $LOAD_COMMAND = $Config{'osname'} eq 'dec_osf' ? \&_load_command_alpha :
                  $Config{'osname'} eq 'linux'   ? \&_load_command_linux :
                                                   \&_load_command_null;
};

#======================================================================#
# Perl apache handlers in order they get executed                      #
#======================================================================#

# Child Init Handler
# Sets up the web registry object - and initializes the timer
sub childInitHandler {
  my $r = shift;
  
  my @X             = localtime;
  my $temp_hostname = hostname;
  my $temp_proc_id  = '' . reverse $$;
  my $temp_seed     = ($temp_proc_id + $temp_proc_id << 15) & 0xffffffff
  ;
  
  while ($temp_hostname =~ s/(.{1,4})//) {
    $temp_seed = $temp_seed ^ unpack("%32L*", $1);
  }
  
  srand(time ^ $temp_seed);
  
  # Create the Registry
  $ENSEMBL_WEB_REGISTRY = EnsEMBL::Web::Registry->new;
  $ENSEMBL_WEB_REGISTRY->timer->set_process_child_count(0);
  $ENSEMBL_WEB_REGISTRY->timer->set_process_start_time(time);
  
  warn sprintf "Child initialised: %7d %04d-%02d-%02d %02d:%02d:%02d\n", $$, $X[5]+1900, $X[4]+1, $X[3], $X[2], $X[1], $X[0] if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
}


sub redirect_to_nearest_mirror {
  ## This does not do an actual HTTP redirect, but sets a cookie that tells the JavaScript to perform a client side redirect after specified time interval
  my $r           = shift;
  my $server_name = $species_defs->ENSEMBL_SERVERNAME;

  # redirect only if we have mirrors, and the ENSEMBL_SERVERNAME is same as headers HOST (this is to prevent redirecting a static server request)
  if (keys %{ $species_defs->ENSEMBL_MIRRORS || {} } && ( $r->headers_in->{'Host'} eq $server_name || $r->headers_in->{'X-Forwarded-Host'} eq $server_name )) {
    my $unparsed_uri    = $r->unparsed_uri;
    my $redirect_flag   = $unparsed_uri =~ /redirect=([^\&\;]+)/ ? $1 : '';
    my $debug_ip        = $unparsed_uri =~ /debugip=([^\&\;]+)/ ?  $1 : '';
    my $redirect_cookie = EnsEMBL::Web::Cookie->retrieve($r, {'name' => 'redirect_mirror'}) || EnsEMBL::Web::Cookie->new($r, {'name' => 'redirect_mirror'});

    # If the user clicked on a link that's explicitly supposed to take him to
    # another mirror, it should have an extra param 'redirect=no' in it. We save
    # the 'redirect' cookie with value 'no' in that case to avoid redirecting
    # any further requests. If there's a param in the url that says redirect=force,
    # we always give precedence to that one. If debug ip param is set, ignore
    # we any existing cookie, deal it as a forced redirect.
    # IMPORTANT: To make debug ip work, make sure there's no cookie set with redirect address
    if ($redirect_flag eq 'force' || $debug_ip) {

      # If the cookie has already been set with its value as the nearest mirror,
      # no further action is required, otherwise if cookie is 'no', clear it's value (don't remove it)
      return DECLINED if $redirect_cookie->value && $redirect_cookie->value ne 'no';
      $redirect_cookie->value('');
      $redirect_cookie->bake;

    } else {
      if ($redirect_flag eq 'no') {
        $redirect_cookie->value('no');
        $redirect_cookie->bake;
      }

      # Now if the redirect_cookie has some value, it is either 'no' or the url path
      # to which the JavaScript should redirect the browser (set later in this subroutine)
      # Either ways, we don't need any further action.
      return DECLINED if $redirect_cookie->value;
    }

    # Getting the correct remote IP address isn't straight forward. We check all the possible
    # ip addresses to get the correct one that is valid and isn't an internal address.
    # If debug ip is provided, then the others are ignored.
    my ($remote_ip) = grep {
      $_ =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/ && !($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255 || $1 == 10 || $1 == 172 && $2 >= 16 && $2 <= 31 || $1 == 192 && $2 == 168);
    } $debug_ip ? $debug_ip : (split(/\s*\,\s*/, $r->headers_in->{'X-Forwarded-For'}), $r->connection->remote_ip);

    # If there is no IP address, don't do any redirect (there's a possibility this is Amazon's loadbalancer trying to do some healthcheck ping)
    return DECLINED unless $remote_ip;

    # Just leave another warning if the GEOCITY file is missing
    my $geocity_file = $species_defs->GEOCITY_DAT || '';
    unless ($geocity_file && -e $geocity_file) {
      warn "MIRROR REDIRECTION FAILED: GEOCITY_DAT file ($geocity_file) was not found.";
      return DECLINED;
    }

    # Get the location record the for remote IP
    my $record;
    eval {
      require Geo::IP;
      my $geo = Geo::IP->open($geocity_file, 'GEOIP_MEMORY_CACHE');
      $record = $geo->record_by_addr($remote_ip) if $geo;
    };
    if ($@ || !$record) {
      warn sprintf 'MIRROR REDIRECTION FAILED: %s', $@ || "Geo::IP could not find details for IP address $remote_ip";
      return DECLINED;
    }

    # Find our the nearest mirror according to the remote IP's location
    my $mirror_map  = $species_defs->ENSEMBL_MIRRORS;

    my $destination = $mirror_map->{$record->country_code || 'MAIN'} || $mirror_map->{'MAIN'};
       $destination = $destination->{$record->region} || $destination->{'DEFAULT'} if ref $destination eq 'HASH';

    # If the user is already on the nearest mirror, save a cookie
    # to avoid doing these checks for further requests from the same machine
    if ($destination eq $server_name) {
      $redirect_cookie->value('no');
      $redirect_cookie->bake;
      return DECLINED;
    }

    # Redirect if the destination mirror is up
    if (grep { $_ eq $destination } @SiteDefs::ENSEMBL_MIRRORS_UP) { # ENSEMBL_MIRRORS_UP contains a list of mirrors that are currently up
      $unparsed_uri   =~ s/(\&|\;)?redirect\=(force|no)//;
      $unparsed_uri  .= $unparsed_uri =~ /\?/ ? ';redirect=no' : '?redirect=no';
      $redirect_cookie->value(sprintf '%s|%s|http://%1$s%s', $destination, $species_defs->ENSEMBL_MIRRORS_REDIRECT_TIME || 9, $unparsed_uri);
      $redirect_cookie->bake;
    }
  }

  return DECLINED;
}

sub postReadRequestHandler {
  my $r = shift; # Get the connection handler

  foreach my $h (@SiteDefs::REQUEST_START_HOOK) {
    no strict;
    $h->($r);
  }

  # Nullify tags
  $ENV{'CACHE_TAGS'} = {};
  
  # Manipulate the Registry
  $ENSEMBL_WEB_REGISTRY->timer->new_child;
  $ENSEMBL_WEB_REGISTRY->timer->clear_times;
  $ENSEMBL_WEB_REGISTRY->timer_push('Handling script', undef, 'Apache');
  
  ## Ajax cookie
  my $cookies = EnsEMBL::Web::Cookie->fetch($r);
  my $width   = $cookies->{'ENSEMBL_WIDTH'} && $cookies->{'ENSEMBL_WIDTH'}->value ? $cookies->{'ENSEMBL_WIDTH'}->value : 0;  
  my $window_width = $cookies->{'WINDOW_WIDTH'} && $cookies->{'WINDOW_WIDTH'}->value ? $cookies->{'WINDOW_WIDTH'}->value : 0;
  
  $r->subprocess_env->{'WINDOW_WIDTH'}          = $window_width; # use for mobile website to determine device windows size
  $r->subprocess_env->{'ENSEMBL_IMAGE_WIDTH'}   = $width || $SiteDefs::ENSEMBL_IMAGE_WIDTH || 800;
  $r->subprocess_env->{'ENSEMBL_DYNAMIC_WIDTH'} = $cookies->{'DYNAMIC_WIDTH'} && $cookies->{'DYNAMIC_WIDTH'}->value ? 1 : $width ? 0 : 1;

  $ENSEMBL_WEB_REGISTRY->timer_push('Post read request handler completed', undef, 'Apache');
  
  # Ensembl DEBUG cookie
  $r->headers_out->add('X-MACHINE' => $SiteDefs::ENSEMBL_SERVER) if $cookies->{'ENSEMBL_DEBUG'};
  
  return;
}

sub cleanURI {
  my $r = shift;
  
  # Void call to populate ENV
  $r->subprocess_env;
  
  # Clean out the uri
  my $uri = $ENV{'REQUEST_URI'};
  
  if ($uri =~ s/[;&]?time=\d+\.\d+//g + $uri =~ s!([^:])/{2,}!$1/!g) {
    $r->parse_uri($uri);
    $r->subprocess_env->{'REQUEST_URI'} = $uri;
  }

  # Clean out the referrer
  my $referer = $ENV{'HTTP_REFERER'};
  
  if ($referer =~ s/[;&]?time=\d+\.\d+//g + $referer =~ s!([^:])/{2,}!$1/!g) {
    $r->subprocess_env->{'HTTP_REFERER'} = $referer;
  }
  
  return DECLINED;
}

sub handler {
  my $r = shift; # Get the connection handler
  
  $ENSEMBL_WEB_REGISTRY->timer->set_name('REQUEST ' . $r->uri);
  
  my $u           = $r->parsed_uri;
  my $file        = $u->path;
  my $querystring = $u->query;
  my @web_cookies = EnsEMBL::Web::Cookie->retrieve($r, map {'name' => $_, 'encrypted' => 1}, $SiteDefs::ENSEMBL_SESSION_COOKIE, $SiteDefs::ENSEMBL_USER_COOKIE);
  my $cookies     = {
    'session_cookie'  => $web_cookies[0] || EnsEMBL::Web::Cookie->new($r, {'name' => $SiteDefs::ENSEMBL_SESSION_COOKIE, 'encrypted' => 1}),
    'user_cookie'     => $web_cookies[1] || EnsEMBL::Web::Cookie->new($r, {'name' => $SiteDefs::ENSEMBL_USER_COOKIE,    'encrypted' => 1})
  };

  my @raw_path = split '/', $file;
  shift @raw_path; # Always empty

  my $redirect = 0;
  ## Redirect to contact form
  if (scalar(@raw_path) == 1 && $raw_path[0] =~ /^contact$/i) {
    $r->uri('/Help/Contact');
    $redirect = 1;
  }  

  ## Fix URL for V/SV Explore pages
  if ($raw_path[1] =~ /Variation/ && $raw_path[2] eq 'Summary') {
    $file =~ s/Summary/Explore/;
    $file .= '?'.$querystring if $querystring;
    $r->uri($file);
    $redirect = 1;
  }  

  ## Simple redirect to VEP

  if ($file =~ /\/info\/docs\/variation\/vep\/vep_script.html/) {
    $r->uri('/info/docs/tools/vep/script/index.html');
    $redirect = 1;
  } elsif (($raw_path[0] && $raw_path[0] =~ /^VEP$/i) || $file =~ /\/info\/docs\/variation\/vep\//) {
    $r->uri('/info/docs/tools/vep/index.html');
    $redirect = 1;
  } elsif ($file =~ /\/info\/docs\/(variation|funcgen|compara|genebuild|microarray)/) {
    $file =~ s/docs/genome/;
    $r->uri($file);
    $redirect = 1;
  }
  
  if ($redirect) {
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
      
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_PERMANENTLY;
  }

  my $aliases = $species_defs->multi_val('SPECIES_ALIASES') || {};
  my %species_map = (
    %$aliases,
    common => 'common',
    multi  => 'Multi',
    perl   => $SiteDefs::ENSEMBL_PRIMARY_SPECIES,
    map { lc($_) => $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$_} } keys %$SiteDefs::ENSEMBL_SPECIES_ALIASES
  );
  
  $species_map{lc $_} = $_ for values %species_map; # Self-mapping
  
  ## Identify the species element, if any
  my ($species, @path_segments);
 
  ## Check for stable id URL (/id/ENSG000000nnnnnn) 
  ## and malformed Gene/Summary URLs from external users
  if (($raw_path[0] && $raw_path[0] =~ /^id$/i && $raw_path[1]) || ($raw_path[0] eq 'Gene' && $querystring =~ /g=/ )) {
    my ($stable_id, $object_type, $db_type, $uri);
    
    if ($raw_path[0] =~ /^id$/i) {
      $stable_id = $raw_path[1];
    } else {
      $querystring =~ /g=(\w+)/;
      $stable_id = $1;
    }
    
    my $unstripped_stable_id = $stable_id;
    
    $stable_id =~ s/\.[0-9]+$// if $stable_id =~ /^ENS/; ## Remove versioning for Ensembl ids

    ## Try to register stable_id adaptor so we can use that db (faster lookup)
    my %db = %{$species_defs->multidb->{'DATABASE_STABLE_IDS'} || {}};
    
    if (keys %db) {
      my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -species => 'multi',
        -group   => 'stable_ids',
        -host    => $db{'HOST'},
        -port    => $db{'PORT'},
        -user    => $db{'USER'},
        -pass    => $db{'PASS'},
        -dbname  => $db{'NAME'}
      );
    }

    ($species, $object_type, $db_type) = Bio::EnsEMBL::Registry->get_species_and_object_type($stable_id);
    
    if (!$species || !$object_type) {
      ## Maybe that wasn't versioning after all!
      ($species, $object_type, $db_type) = Bio::EnsEMBL::Registry->get_species_and_object_type($unstripped_stable_id);
      $stable_id = $unstripped_stable_id if($species && $object_type);
    }
    
    if ($object_type) {
      $uri = $species ? "/$species/" : '/Multi/';
      
      if ($object_type eq 'Gene') {
        $uri .= "Gene/Summary?g=$stable_id";
      } elsif ($object_type eq 'Transcript') {
        $uri .= "Transcript/Summary?t=$stable_id";
      } elsif ($object_type eq 'Translation') {
        $uri .= "Transcript/ProteinSummary?t=$stable_id";
      } elsif ($object_type eq 'GeneTree') {
        $uri = "/Multi/GeneTree/Image?gt=$stable_id";
      } elsif ($object_type eq 'Family') {
        $uri = "/Multi/Family/Details?fm=$stable_id";
      } else {
        $uri .= "psychic?q=$stable_id";
      }
      
      $r->uri($uri);
      $r->headers_out->add('Location' => $r->uri);
      $r->child_terminate;
      
      $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
      return HTTP_MOVED_PERMANENTLY;
    }
    
    ## In case the given ID is retired, which means no species 
    ## can be returned by the API call above
    $r->uri('/');
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return NOT_FOUND;
  }

  my %lookup = map { $_ => 1 } $species_defs->valid_species;
  my $lookup_args = {
    sd     => $species_defs,
    map    => \%species_map,
    lookup => \%lookup,
    uri    => $r->unparsed_uri,
  };
  
  foreach (@raw_path) {
    $lookup_args->{'dir'} = $_;
    
    my $check = _check_species($lookup_args);
    
    if ($check && $check =~ /^http/) {
      $r->headers_out->set( Location => $check );
      return REDIRECT;
    } elsif ($check && !$species) {
      $species = $_;
    } else {
      push @path_segments, $_;
    }
  }
  
  if (!$species) {
    if (grep /$raw_path[0]/, qw(Multi das common default)) {
      $species = $raw_path[0];
      shift @path_segments;
    } elsif ($path_segments[0] eq 'Gene' && $querystring) {
      my %param = split ';|=', $querystring;
      
      if (my $gene_stable_id = $param{'g'}) {
        my ($id_species) = Bio::EnsEMBL::Registry->get_species_and_object_type($gene_stable_id);
            $species     = $id_species if $id_species;
      }  
    }
  }
  
  @path_segments = @raw_path unless $species;
  
  # Some memcached tags (mainly for statistics)
  my $prefix = '';
  my @tags   = map { $prefix = join '/', $prefix, $_; $prefix; } @path_segments;
  
  if ($species) {
    @tags = map {( "/$species$_", $_ )} @tags;
    push @tags, "/$species";
  }
  
  $ENV{'CACHE_TAGS'}{$_} = $_ for @tags;
  
  my $Tspecies  = $species;
  my $script    = undef;
  my $path_info = undef;
  my $species_name = $species_map{lc $species};
  my $return;
  
  if (!$species && $raw_path[-1] !~ /\./) {
    $species      = 'common';
    $species_name = 'common';
    $file         = "/common$file";
    $file         =~ s|/$||;
  }
  
  if ($raw_path[0] eq 'das') {
    my ($das_species) = split /\./, $path_segments[0];
    
    $return = EnsEMBL::Web::Apache::DasHandler::handler_das($r, $cookies, $species_map{lc $das_species}, \@path_segments, $querystring);
    
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler for DAS scripts finished', undef, 'Apache');
  } elsif ($species && $species_name) { # species script
    $return = EnsEMBL::Web::Apache::SpeciesHandler::handler_species($r, $cookies, $species_name, \@path_segments, $querystring, $file, $species_name eq $species);
    
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler for species scripts finished', undef, 'Apache');
    
    shift @path_segments;
    shift @path_segments;
  }
  
  if (defined $return) {
    if ($return == OK) {
      push_script_line($r) if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
      
      $r->push_handlers(PerlCleanupHandler => \&cleanupHandler_script);
      $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler);
    }
    
    return $return;
  }
  
  $species = $Tspecies;
  $script = join '/', @path_segments;

  # Permanent redirect for old species home pages:
  # e.g. /Homo_sapiens or Homo_sapiens/index.html -> /Homo_sapiens/Info/Index
  if ($species && $species_name && (!$script || $script eq 'index.html')) {
    $r->uri($species_name eq 'common' ? 'index.html' : "/$species_name/Info/Index");
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_PERMANENTLY;
  }
  
  #commenting this line out because we do want biomart to redirect. If this is causing problem put it back.
  #return DECLINED if $species eq 'biomart' && $script =~ /^mart(service|results|view)/;

  my $path = join '/', $species || (), $script || (), $path_info || ();
  
  $r->uri("/$path");
  
  my $filename = $MEMD ? $MEMD->get("::STATIC::$path") : '';
  
  # Search the htdocs dirs for a file to return
  # Exclude static files (and no, html is not a static file in ensembl)
  if ($path !~ /\.(\w{2,3})$/) {
    if (!$filename) {
      foreach my $dir (grep { -d $_ && -r $_ } @SiteDefs::ENSEMBL_HTDOCS_DIRS) {
        my $f = "$dir/$path";
        
        if (-d $f || -r $f) {
          $filename = -d $f ? '! ' . $f : $f;
          $MEMD->set("::STATIC::$path", $filename, undef, 'STATIC') if $MEMD;
          
          last;
        }
      }
    }
  }
  
  if ($filename =~ /^! (.*)$/) {
    $r->uri($r->uri . ($r->uri      =~ /\/$/ ? '' : '/') . 'index.html');
    $r->filename($1 . ($r->filename =~ /\/$/ ? '' : '/') . 'index.html');
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_TEMPORARILY;
  } elsif ($filename) {
    $r->filename($filename);
    $r->content_type('text/html');
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "OK"', undef, 'Apache');
    
    EnsEMBL::Web::Apache::SSI::handler($r, $cookies);
    
    return OK;
  }
  
  # Give up
  $ENSEMBL_WEB_REGISTRY->timer_push('Handler "DECLINED"', undef, 'Apache');
  
  return DECLINED;
}

sub _check_species {
## Do this in a private function so it's more easily pluggable, e.g. on Pre!
## This default version just checks if this is a valid species for the site
  my $args = shift;
  return $args->{'lookup'}{$args->{'map'}{lc $args->{'dir'}}};
}

sub logHandler {
  my $r = shift;
  my $T = time;
  
  $r->subprocess_env->{'ENSEMBL_CHILD_COUNT'}  = $ENSEMBL_WEB_REGISTRY->timer->get_process_child_count;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_START'} = sprintf '%0.6f', $T;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_END'}   = sprintf '%0.6f', $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_TIME'}  = sprintf '%0.6f', $T - $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  
  return DECLINED;
}

sub cleanupHandler {
  my $r = shift;  # Get the connection handler
  
  foreach my $h (@SiteDefs::REQUEST_END_HOOK) {
    no strict;
    $h->($r);
  }
  return if $r->subprocess_env->{'ENSEMBL_ENDTIME'};
  
  my $end_time   = time;
  my $start_time = $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  my $length     = $end_time - $start_time;
  
  if ($length >= $SiteDefs::ENSEMBL_LONGPROCESS_MINTIME) {
    my $u      = $r->parsed_uri;
    my $file   = $u->path;
    my $query  = $u->query . $r->subprocess_env->{'ENSEMBL_REQUEST'};
    my $size;
    
    if ($Apache2::SizeLimit::HOW_BIG_IS_IT) {
      $size = &$Apache2::SizeLimit::HOW_BIG_IS_IT();
    } else {
      ($size) = Apache2::SizeLimit->_check_size;
    }
    
    $r->subprocess_env->{'ENSEMBL_ENDTIME'} = $end_time;
    
    if ($SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS) {
      my @X = localtime($start_time);
      
      warn sprintf(
        "LONG PROCESS: %12s DT:  %04d-%02d-%02d %02d:%02d:%02d Time: %10s Size: %10s\nLONG PROCESS: %12s REQ: %s\nLONG PROCESS: %12s IP:  %s  UA: %s\n", 
        $$, $X[5]+1900, $X[4]+1, $X[3], $X[2], $X[1], $X[0], $length, $size, 
        $$, "$file?$query", 
        $$, $r->subprocess_env->{'HTTP_X_FORWARDED_FOR'}, $r->headers_in->{'User-Agent'}
      );
    }
  }

  # Now we check if the die file has been touched...
  my $die_file = $SiteDefs::ENSEMBL_SERVERROOT . '/logs/ensembl.die';
  
  if (-e $die_file) {
    my @temp = stat $die_file;
    my $file_mod_time = $temp[9];
    if ($file_mod_time >= $ENSEMBL_WEB_REGISTRY->timer->get_process_start_time) {
      warn sprintf "KILLING CHILD %10s\n", $$;
      
      if ($Apache2::SizeLimit::IS_WIN32 || $Apache2::SizeLimit::WIN32) {
        CORE::exit(-2);
      } else {
        $r->child_terminate;
      }
    }
    
    return DECLINED;
  }
}

sub cleanupHandler_script {
  my $r = shift;
  
  $ENSEMBL_WEB_REGISTRY->timer_push('Cleaned up', undef, 'Cleanup');
  
  warn $ENSEMBL_WEB_REGISTRY->timer->render if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_PERL_PROFILER;
  
  push_script_line($r, 'ENDSCR', sprintf '%10.3f', time - $r->subprocess_env->{'LOG_TIME'}) if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
  
  cleanupHandler_blast($r) if $SiteDefs::ENSEMBL_BLASTSCRIPT;
}

sub cleanupHandler_blast {
  my $r = shift;
  
  my $directory = $SiteDefs::ENSEMBL_TMP_DIR_BLAST . '/pending';
  my $FLAG  = 0;
  my $count = 0;
  my $ticket;
  my $_process_blast_called_at = time;

  $ticket = $ENV{'ticket'};
  
  # Lets work out when to run this!
  my $run_blast;
  my $loads = _get_loads();
  my $seconds_since_last_run = (time - $BLAST_LAST_RUN);

  if ($ticket) {
    if (_run_blast_ticket($loads, $seconds_since_last_run)) {
      $FLAG = 1;
      $BLAST_LAST_RUN = time;
    }
  } else {
    # Current run blasts
    if (_run_blast_no_ticket($loads, $seconds_since_last_run)) {
      $BLAST_LAST_RUN = time;
      $FLAG = 1;
    }
  }
  
  while ($FLAG) {
    $count++;
    $FLAG = 0;
    
    if (opendir(DH, $directory)) {
      while (my $FN = readdir(DH)) {
        my $file = "$directory/$FN";
        
        next unless -f $file; # File
        next if -z $file;     # Contains something
        
        my @STAT = stat $file;
        
        next if $STAT[8]+5 > time; # Was last modified more than 5 seconds ago
        next if $ticket && $file !~ /$ticket/;
        
        # We have a ticket
        open  FH, $file;
        
        flock FH, LOCK_EX;
        my $blast_file = <FH>;
        chomp $blast_file;
        
        $blast_file = $1 if $blast_file =~ /^([\/\w\.-]+)/;
        
        (my $FILE2 = $file) =~ s/pending/parsing/;
        
        rename $file, $FILE2;
        
        (my $FILE3 = $file) =~ s/pending/sent/;
        
        unlink $FILE3;
        
        flock FH, LOCK_UN;
        
        my $COMMAND = "$SiteDefs::ENSEMBL_BLASTSCRIPT $blast_file $FILE2";
        
        warn "BLAST: $COMMAND";
        
        `$COMMAND`; # Now we parse the blast file
        
        if ($ticket && ($_process_blast_called_at + 30 > time)) {
          $loads = _get_loads();
          $FLAG = 1 if $count < 15;
        }
        
        last;
      }
      
      closedir(DH);
    }
  }
}

sub childExitHandler {
  my $r = shift;
  
  if ($SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS) {
    my $size;
    
    if ($Apache2::SizeLimit::HOW_BIG_IS_IT) {
      $size = &$Apache2::SizeLimit::HOW_BIG_IS_IT();
    } else {
      ($size) = Apache2::SizeLimit->_check_size;
    }
    
    warn sprintf "Child %9d: - reaped at      %30s;  Time: %11.6f;  Req:  %4d;  Size: %8dK\n",
      $$, '' . gmtime, time-$ENSEMBL_WEB_REGISTRY->timer->get_process_start_time,
      $ENSEMBL_WEB_REGISTRY->timer->get_process_child_count,
      $size
  }
}

sub push_script_line {
  my $r      = shift;
  my $prefix = shift || 'SCRIPT';
  my $extra  = shift;
  my @X      = localtime;
  
  warn sprintf(
    "%s: %s%9d %04d-%02d-%02d %02d:%02d:%02d %s %s\n",
    $prefix, hostname, $$,
    $X[5] + 1900, $X[4] + 1, $X[3], $X[2], $X[1], $X[0],
    $r->subprocess_env->{'REQUEST_URI'}, $extra
  );
  
  $r->subprocess_env->{'LOG_TIME'} = time;
}

#======================================================================#
# BLAST Support functionality - TODO: update before implementing!      #
#======================================================================#

sub _run_blast_no_ticket {
  my ($loads, $seconds_since_last_run) = @_;
  return $loads->{'blast'} < 3 && rand $loads->{'httpd'} < 10 && rand $seconds_since_last_run > 1;
}

sub _run_blast_ticket {
  my ($loads, $seconds_since_last_run) = @_;
  return $loads->{'blast'} < 8;
}

sub _get_loads {
  return {
    blast => &$LOAD_COMMAND('parse_blast.pl'),
    httpd => &$LOAD_COMMAND('httpd')
  };
}

sub  _load_command_null {
  return 1;
}

sub _load_command_alpha {
  my $command = shift;
  my $VAL = `ps -A | grep $command | wc -l`;
  
  return $VAL - 1;
}

sub _load_command_linux {
  my $command = shift;
  my $VAL = `ps --no-heading -C $command  | wc -l`;
  
  return $VAL + 0;
}

sub _referrer_is_mirror {
## Mirror hash is now multi-dimensional, so we have to recurse into it
    my ( $ensembl_mirrors, $referrer ) = @_;
    map { ref $_ eq 'HASH' ? _referrer_is_mirror( $_, $referrer ) : $referrer eq $_ ? return 'true' : undef }
      values %$ensembl_mirrors;
}

1;
