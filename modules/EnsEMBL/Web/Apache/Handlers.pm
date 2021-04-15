=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

### This handler handles all dynamic page request including .html requests

use strict;
use warnings;
no warnings qw(uninitialized);

use Apache2::Const qw(:common :http :methods);
use Apache2::SizeLimit;
use Apache2::Connection;
use Apache2::URI;
use APR::URI;
use Config;
use Fcntl ':flock';
use Sys::Hostname;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use Storable;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Exceptions;

use EnsEMBL::Web::Apache::SSI;
use EnsEMBL::Web::Apache::SpeciesHandler;
use EnsEMBL::Web::Apache::ServerError;
use EnsEMBL::Web::Apache::Extension;

our $start_time;
BEGIN { $start_time = time; }
use Preload;
#BEGIN { warn sprintf("preload took %dms\n",(time-$start_time)*1000); }


our $species_defs = EnsEMBL::Web::SpeciesDefs->new;

sub get_postread_redirect_uri {
  ## Gets called at PostReadRequest stage and returns a new URI in case a TEMPORARY external HTTP redirect has to be performed without executing to the actual handler
  ## Used to perform any mirror site redirects etc
  ## Gets called for all the requests
  ## @param Apache2::RequestRec request object
  ## @return URI string if redirection required, undef otherwise
  ## In a plugin, use this function with PREV to add plugin specific rules
}

sub get_rewritten_uri {
  ## Receives the current URI and returns a new URI in case it has to be rewritten
  ## The same request itself is handled according to the rewritten URI instead of making an external redirect request
  ## @param Apache2::RequestRec request object
  ## @param URI string
  ## @return URI string if modified, undef otherwise
  ## In a plugin, use this function with PREV to add plugin specific rules
}

sub get_redirect_uri {
  ## Receives the current URI and returns a new URI in case a TEMPORARY external HTTP redirect has to be performed on that while executing to the actual handler
  ## Gets called for only non-Static requests
  ## @param Apache2::RequestRec request object
  ## @param URI string
  ## @return URI string if redirection required, undef otherwise
  ## In a plugin, use this function with PREV to add plugin specific rules
  my ($r, $uri) = @_;

  ## Redirect to OLS
  if ($uri =~ m|^/glossary/|) {
    my $ols = $SiteDefs::ENSEMBL_GLOSSARY_URL;
    if ($uri =~ m|ENSGLOSSARY_(\d+)|) {
      my $id = $1;
      return $ols.'/terms?iri=http%3A%2F%2Fensembl.org%2Fglossary%2FENSGLOSSARY_'.$id;
    }
    else {
      return $ols;
    }
  }

  ## Redirect to contact form
  if ($uri =~ m|^/contact\?$|) {
    return '/Help/Contact';
  }

  ## Fix URL for V/SV Explore pages
  if ($uri =~ m|Variation/Summary|) {
    return $uri =~ s/Summary/Explore/r;
  }

  if ($uri =~ /\/Multi\/psychic/) {
    return $uri =~ s/\/Multi\/psychic/\/Multi\/Psychic/r;
  }
  
  ## Handle id lookups from ensemblgenomes.org to the corresponding page
  if ($uri =~ /\/common\/psychic/ && $uri =~ /[\&\;\?]{1}q=([^\&\;]+)/ ) {
    return stable_id_redirect_uri('id', $1)
  }

  ## quick fix for solr autocomplete js bug
  if ($uri =~ /undefined\//) {
    return $uri =~ s/undefined\///r;
  }

  ## Trackhub short URL
  if ($uri =~ /^\/Trackhub(\/|\?|$)/i) {
    return $uri =~ s/trackhub/UserData\/TrackHubRedirect/ri;
  }

  ## VEP shortlink
  if ($uri =~ m|^/vep$|) {
    return '/info/docs/tools/vep/index.html';
  }

  ## Redirect moved documentation
  if ($uri =~ /\/info\/docs\/(variation|funcgen|compara|genebuild|microarray)/) {
     return $uri =~ s/docs/genome/r;
 }

  ## Broken links in old genebuild PDFs
  if ($uri =~ /\/info\/docs\/genebuild\/genome_annotation.html/) {
     return $uri =~ s/genome_annotation/index/r;
 }

  ## For stable id URL (eg. /id/ENSG000000nnnnnn) or malformed Gene URL with g param
  if ($uri =~ m/^\/(id|loc)\/(.+)/i || ($uri =~ m|^/Gene\W| && $uri =~ /[\&\;\?]{1}(g)=([^\&\;]+)/)) {
    return stable_id_redirect_uri($1 eq 'loc' ? 'loc' : 'id', $2);
  }

  ## Redirect to live site if this instance has no Doxygen files
  if ($uri =~ /Doxygen/ && !(-e $species_defs->ENSEMBL_SERVERROOT.'/public-plugins/docs/htdocs'.$uri)) {
    return '//www.ensembl.org/'.$uri;
  } 

  return undef;
}

sub stable_id_redirect_uri {
  ## Constructs complete URI according to a given stable id
  ## @param Type of short url - id or loc
  ## @param Stable ID string
  my ($url_type, $stable_id) = @_;

  my ($species, $object_type, $db_type, $retired, $uri);

  my $unstripped_stable_id = $stable_id;

  $stable_id =~ s/\.[0-9]+$// if $stable_id =~ /^ENS/; # Remove versioning for Ensembl ids

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

  ($species, $object_type, $db_type, $retired) = Bio::EnsEMBL::Registry->get_species_and_object_type($stable_id, undef, undef, undef, undef, 1);

  if (!$species || !$object_type) {
    ## Maybe that wasn't versioning after all!
    ($species, $object_type, $db_type, $retired) = Bio::EnsEMBL::Registry->get_species_and_object_type($unstripped_stable_id, undef, undef, undef, undef, 1);
    $stable_id = $unstripped_stable_id if $species && $object_type;
  }

  if ($object_type) {

    # get the correct url name for species if species present
    $species &&= ($species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP') || {})->{lc $species} || $species;

    if ($url_type eq 'loc' && $species && !$retired && $object_type =~ /^(Gene|Transcript|Translation)$/) {
      $uri = sprintf '/%s/Location/View?%s=%s', $species, $object_type eq 'Gene' ? 'g' : 't', $stable_id;

    } else {

      $uri = sprintf '/%s/', $species || 'Multi';

      if ($object_type eq 'Gene') {
        $uri .= sprintf 'Gene/%s?g=%s', $retired ? 'Idhistory' : 'Summary', $stable_id;
      } elsif ($object_type eq 'Transcript') {
        $uri .= sprintf 'Transcript/%s?t=%s',$retired ? 'Idhistory' : 'Summary', $stable_id;
      } elsif ($object_type eq 'Translation') {
        $uri .= sprintf 'Transcript/%s?t=%s', $retired ? 'Idhistory/Protein' : 'ProteinSummary', $stable_id;
      } elsif ($object_type eq 'GeneTree') {
        $uri = "/Multi/GeneTree/Image?gt=$stable_id"; # no history page!
      } elsif ($object_type eq 'Family') {
        $uri = "/Multi/Family/Details?fm=$stable_id"; # no history page!
      } else {
        $uri .= "Psychic?q=$stable_id";
      }
    }
  }

  return $uri || "/Multi/Psychic?q=$stable_id";
}

sub parse_ensembl_uri {
  ## Parses and saves uri components in subprocess_env if not already parsed
  ## @param Apache2::RequestRec request object
  ## @return undef if parsed successfully or a URL string if a redirect is needed after cleaning the species name
  my $r = shift;

  # return if already parsed
  return if $r->subprocess_env('ENSEMBL_PATH');

  my $parsed_uri  = $r->parsed_uri;
  my $uri_path    = $parsed_uri->path // '';
  my $uri_query   = $parsed_uri->query // '';

  # if there's nothing to parse, it's a homepage request - redirect to index.html in that case
  return join '?', '/index.html', $uri_query || () if $uri_path eq '/';

  my $species_alias_map = $species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP') || {};
  my %valid_species_map = map { $_ => 1 } $species_defs->valid_species;

  # filter species alias map to remove any species that are not present in a list returned by $species_defs->valid_species
  $valid_species_map{$species_alias_map->{$_}} or delete $species_alias_map->{$_} for keys %$species_alias_map;

  # extract the species name from the raw path segments, and leave the remainders as our final path segments
  my ($species, $species_alias);
  my @path_segments = grep { $_ ne '' && ($species || !($species = $species_alias_map->{lc $_} and $species_alias = $_)) } split '/', $uri_path;

  # if species name provided in the url is not the formal species url name, it's time to redirect the request to the correct species url
  return '/'.join('?', join('/', $species, @path_segments), $uri_query eq '' ? () : $uri_query) if $species && $species ne $species_alias;

  $r->subprocess_env('ENSEMBL_SPECIES', $species) if $species;
  $r->subprocess_env('ENSEMBL_PATH',  '/'.join('/', @path_segments));
  $r->subprocess_env('ENSEMBL_QUERY', $uri_query);

  return undef;
}

sub get_sub_handlers {
  ## Finds out the possible sub handlers that could handle this request
  ## @param Apache2::RequestRec request object
  ## @param Species name (string)
  ## @param Arrayref of path segments
  ## @return List containing possibe handlers and species (possibly modified)
  my ($r, $species, $path_seg) = @_;

  my @combinations;

  # Try SpeciesHandler in all cases if species is present or the file path is not an explicit .html path
  if ($species || $path_seg->[-1] !~ /\.html$/) {

    push @combinations, {
      'handler' => 'EnsEMBL::Web::Apache::SpeciesHandler',
      'species' => !$species || $species eq 'common' ? 'Multi' : $species
    };
  }

  # Finally try the SSI handler if species doesn't exist
  if (!$species) {
    push @combinations, {
      'handler' => 'EnsEMBL::Web::Apache::SSI',
    };
  }

  return @combinations;
}

sub set_remote_ip {
  ## Sets the ENSEMBL_REMOTE_ADDR env variable to the possibly most accurate client's address
  my $r   = shift;
  my $ip  = $r->subprocess_env('HTTP_X_FORWARDED_FOR') || $r->subprocess_env('HTTP_X_CLUSTER_CLIENT_IP') || $r->subprocess_env('HTTP_CLIENT_IP') || $r->subprocess_env('REMOTE_ADDR') || '';

  ($ip)   = split /\s*\,\s*/, $ip;

  $r->subprocess_env('ENSEMBL_REMOTE_ADDR', $ip);
}

sub http_redirect {
  ## Perform an http redirect
  ## @param Apache2::RequestRec request object
  ## @param URI string to redirect to
  ## @param Flag kept on for permanent redirects
  ## @return HTTP_MOVED_TEMPORARILY or HTTP_MOVED_PERMANENTLY
  my ($r, $redirect_uri, $permanent) = @_;
  $r->uri($redirect_uri);
  $r->headers_out->add('Location' => $r->uri);

  return $permanent ? HTTP_MOVED_PERMANENTLY : HTTP_MOVED_TEMPORARILY;
}

sub time_str {
  ## @return Printable time string
  return strftime("%a %b %d %H:%M:%S %Y", @_ ? localtime(shift) : localtime);
}

sub request_start_hook {
  ## Subroutine hook to be called when the request handling starts
  ## @param Apache2::RequestRec request object
  ## In a plugin, use this function with PREV to plugin some code to be run before the request is handled
}

sub request_end_hook {
  ## Subroutine hook to be called when the request handling finishes
  ## @param Apache2::RequestRec request object
  ## In a plugin, use this function with PREV to plugin some code to be run after the request is served
}

#########################################
###         mod_perl handlers         ###
#########################################

sub childInitHandler {
  ## This handler gets called by Apache when initialising an Apache child process
  ## @param APR::Pool object
  ## @param Apache2::ServerRec server object
  # Storable defaults are now too small. Ideally these would be configurable,
  # perhaps in SiteDefs.
  $Storable::recursion_limit = 20474;
  $Storable::recursion_limit_hash = 12278;
  srand;
  warn sprintf "[%s] Child initialised: %d\n", time_str, $$ if $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;

  return OK;
}

sub postReadRequestHandler {
  ## This handler gets called immediately after the request has been read and HTTP headers were parsed
  ## @param Apache2::RequestRec request object
  my $r = shift;

  return OK if $r->unparsed_uri eq '*';

  # VOID request to populate %ENV
  $r->subprocess_env;

  # Set possibly most accurate remote IP address
  set_remote_ip($r);

  # Any redirect needs to be performed at this stage?
  if (my $redirect_uri = get_postread_redirect_uri($r)) {
    $r->subprocess_env('LOG_REQUEST_IGNORE', 1);
    return http_redirect($r, $redirect_uri);
  }

  # save request start time for logs
  $r->subprocess_env('LOG_REQUEST_START', sprintf('%0.6f', time));

  # run any plugged-in code
  request_start_hook($r);

  Bio::EnsEMBL::Registry->set_reconnect_when_lost();

  return OK;
}

sub transHandler {
  ## This handler gets called to perform the manipulation of a request's URI
  ## @param Apache2::RequestRec request object
  my $r   = shift;
  my $uri = $r->unparsed_uri;

  return DECLINED if $uri eq '*';

  # apply any uri rewrite rules
  if (my $modified = get_rewritten_uri($r, $uri)) {
    $r->parse_uri($modified);
  }

  # save raw uri for logs
  $r->subprocess_env('LOG_REQUEST_URI', $r->unparsed_uri);

  return DECLINED;
}

our (%HOT_DBS,%EXPULSIONS);

sub check_port_exhaustion {
  my $count = 0;
  open(SOCKETS,"/proc/net/tcp") || return 0;
  while(<SOCKETS>) { $count++; }
  close SOCKETS;
  return $count;
}

sub lb_force_down {
  foreach my $f (@{$SiteDefs::ENSEMBL_FORCE_DOWN||[]}) {
    return 1 if -e $f;
  }
  return 0;
}

sub tidy_databases {
  my $debug = $SiteDefs::ENSEMBL_DB_TIDY_DEBUG;

  # tidy up unused databases
  my %databases;
  foreach my $dba ( @{Bio::EnsEMBL::Registry->get_all_DBAdaptors()}){
    my $dbc = $dba->dbc;
    next unless $dbc->connected();
    my $dsn = $dbc->_driver_object->connect_params($dbc)->{'dsn'};
    ($HOT_DBS{$dsn}||=0)++;
    $databases{$dsn} = $dbc;
  }

  my $tokill = scalar(keys %databases)-$SiteDefs::ENSEMBL_DB_IDLE_LIMIT;

  my $ports_used = check_port_exhaustion;
  if($ports_used < 10000) {
    foreach my $dsn (sort { $HOT_DBS{$a} <=> $HOT_DBS{$b} } keys %HOT_DBS) {
      last if $tokill <= 0;
      next unless $databases{$dsn};
      warn "disconnecting $dsn\n" if $debug;
      $databases{$dsn}->disconnect_if_idle();
      ($EXPULSIONS{$dsn}||=0)++;
      $tokill--;
    }
  } else {
    warn "not disconnecting due to impending port exhaustion.\n" if $debug;
  }

  # A db will have been loaded EXPULSIONS+1 times. It will have been used
  # HOT_DBS times. miss rate = Sum{ (EXPULSIONS+1)/HOT_DBS }
  if($debug) {
    my ($misses,$total) = (0,0);
    foreach my $dsn (keys %HOT_DBS) {
      $misses += ($EXPULSIONS{$dsn}||0)+1;
      $total += $HOT_DBS{$dsn};
    }
    warn sprintf("hit rate %d%%\n",($total-$misses)*100/$total) if $total;
    warn sprintf("%d ports in use\n",$ports_used);
  }
}

sub selfcheck_down {
  # TODO check stuff
  return 0;
}

sub howsitgoing {
  my ($r) = @_;

  $r->print("\n");

  my $uptime = time - $start_time;
  my $host = hostname;
  $r->print("uptime: $uptime\n$host\n");
}

sub handler {
  ## This is the main handler that gets called to generate a response for the given request
  ## @param Apache2::RequestRec request object
  ## @return One of the Apache2::Const common/http codes
  my $r   = shift;
  my $uri = $r->unparsed_uri;

  # extension uris
  if ($uri =~ m|^/x/|) {
    if (my $redirect = EnsEMBL::Web::Apache::Extension::handle($r, $uri)) {
      return http_redirect($r, $redirect);
    }
    return OK;
  }

  if($uri eq '/__howsitgoing') {
    $r->content_type('text/plain');
    if(lb_force_down() || selfcheck_down()) {
      $r->status(HTTP_SERVICE_UNAVAILABLE);
      $r->print("503 Sticky wicket\n");
      return HTTP_SERVICE_UNAVAILABLE; # 503, not 500, so e! deosn't catch it
    } else {
      $r->print("200 Mustn't grumble\n");
      howsitgoing($r);
      return OK;
    }
  }

  # handle any redirects
  if (my $redirect = get_redirect_uri($r, $uri)) {
    return http_redirect($r, $redirect);
  }

  # populate subprocess_env with species, path and query or perform a redirect to a rectified url
  if (my $redirect = parse_ensembl_uri($r)) {
    return http_redirect($r, $redirect, 1);
  }

  # get these values as recently saved by parse_ensembl_uri subroutine
  my $species   = $r->subprocess_env('ENSEMBL_SPECIES');
  my $path      = $r->subprocess_env('ENSEMBL_PATH');
  my $query     = $r->subprocess_env('ENSEMBL_QUERY');
  my $path_seg  = [ grep { $_ ne '' } split '/', $path ];

  # other species-like path segments
  if (!$species && $path_seg->[0] && grep $_ eq $path_seg->[0], qw(Multi common)) {
    $species = shift @$path_seg;
  }

  # ENSEMBL_PATH may need an update
  $r->subprocess_env('ENSEMBL_PATH', '/'.join('/', @$path_seg));

  # find the possible handlers according to species and path
  my @handler_combinations = get_sub_handlers($r, $species, $path_seg);
  my $response_code;

  for (@handler_combinations) {
    my $handler = $_->{'handler'};
    my $species = $_->{'species'};

    # there is a possibility ENSEMBL_SPECIES needs an updated
    $r->subprocess_env('ENSEMBL_SPECIES', $species);

    # delegate request to the required handler and get the response status code
    try {
      $response_code = $handler->can('handler')->($r, $species_defs);
    } catch {
      EnsEMBL::Web::Apache::ServerError::handler($r, $species_defs, $_);
      $response_code = OK; # EnsEMBL::Web::Apache::ServerError sets the actual status code itself
    };

    # check for any permanent redirects requested by the code
    if (my $redirect = $r->subprocess_env('ENSEMBL_REDIRECT_PERMANENT')) {
      return http_redirect($r, $redirect, 1);
    }

    # check for any temporary redirects requested by the code
    if (my $redirect = $r->subprocess_env('ENSEMBL_REDIRECT_TEMPORARY')) {
      return http_redirect($r, $redirect);
    }

    last if defined $response_code;
  }

  # give up if no response code was set by any of the handlers
  if (not defined $response_code) {
    # when the request is declined, it will eventually be treated by Apache as a 404,
    # at which point its uri will be re-written to /Error (see httpd.conf);
    # so let's keep the original uri in a custom header
    # (not using the standard Referer header, because a referrer is a full url, with protocol and hostname)
    $r->headers_in->add('X-Declined-From' => $r->unparsed_uri);
    return DECLINED;
  }

  # kill off the process when it grows too large
  # Rely on OOB now. (Mart exceeds what this package can handle)
#  $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler) if $response_code == OK;

  tidy_databases();

  return $response_code;
}

sub logHandler {
  ## This handler gets called once the response is genetated, irrespective of the return type of the previous handler.
  ## @param Apache2::RequestRec request object
  my $r = shift;
  my $t = time;

  return DECLINED if $r->unparsed_uri eq '*';
  return DECLINED if $r->subprocess_env('LOG_REQUEST_IGNORE');

  # more vars for logs
  $r->subprocess_env('LOG_REQUEST_END',   sprintf('%0.6f', $t));
  $r->subprocess_env('LOG_REQUEST_TIME',  sprintf('%0.6f', $t - $r->subprocess_env('LOG_REQUEST_START')));

  return DECLINED;
}

sub out_of_bounds {
  my $lim = $SiteDefs::ENSEMBL_OOB_LIMITS;
  my $actual = {};
  # Too many file descriptors left open?
  if($lim->{'fd'}) {
    $actual->{'fd'} = scalar(my @x = (glob "/proc/$$/fd/*"));
  }
  # Too much memory in use?
  if($lim->{'memory'}) {
    if(open(STATM,'<',"/proc/$$/statm")) {
      my @data = split(/\s+/,<STATM>);
      close STATM;
      $actual->{'memory'} = $data[0] /1024 *4; # 4kb -> Mb
    }
  }
  # Too old?
  if($lim->{'age'}) {
    $actual->{'age'} = time - (stat "/proc/$$/stat")[10];
  }
  # ADD YOUR TEST HERE! 
  # do the checks
  foreach my $k (keys %$actual) {
    return "$k: ($actual->{$k} > $lim->{$k})" if $actual->{$k} > $lim->{$k};
    #warn "$k: actual=$actual->{$k} limit=$lim->{$k}\n";
  }
  # in-bounds
  return undef;
}

sub cleanupHandler {
  ## This handler gets called immediately after the request has been served (the client went away) and before the request object is destroyed.
  ## Any time consuming logging process should be done in this handler since the request connection has actually been closed by now.
  ## @param Apache2::RequestRec request object
  my $r     = shift;
  my $uuri  = $r->unparsed_uri;

  return OK if !defined $uuri || $uuri =~ m/^(\*|\/Crash|\/Error)/;

  # run any plugged-in code
  request_end_hook($r);

  # no need to go further if debug flag is off
  return OK unless $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;

  # if LOG_REQUEST_IGNORE is set true by the code, don't log the request url
  return OK if $r->subprocess_env('LOG_REQUEST_IGNORE');

  my $start_time  = $r->subprocess_env('LOG_REQUEST_START');
  my $time_taken  = $r->subprocess_env('LOG_REQUEST_TIME') || 0;
  my $uri         = $r->subprocess_env('LOG_REQUEST_URI');

  warn sprintf "REQUEST(%s): [served at %s by %s in %sms] %s\n", $r->method_number == M_POST ? 'P' : 'G', time_str($start_time), $$, int(1000*$time_taken), $uri;

  if ($time_taken >= $SiteDefs::ENSEMBL_LONGPROCESS_MINTIME) {

    my ($size) = $Apache2::SizeLimit::HOW_BIG_IS_IT ? $Apache2::SizeLimit::HOW_BIG_IS_IT->() : Apache2::SizeLimit->_check_size;

    warn sprintf(
      "LONG PROCESS: %12s AT: %s  TIME: %s  SIZE: %s\nLONG PROCESS: %12s REQ: %s\nLONG PROCESS: %12s IP: %s  UA: %s\n",
      $$, time_str($start_time), $time_taken, $size,
      $$, $uri,
      $$, $r->subprocess_env('ENSEMBL_REMOTE_ADDR') || 'unknown', $r->headers_in->{'User-Agent'} || 'unknown'
    );
  }

  if((my $oob = out_of_bounds())) {
    warn "TERMINATING PROCESS DUE TO OOB [$$]: $oob\n";
    $r->child_terminate;
  }

  return OK;
}

sub childExitHandler {
  ## This handler gets called when the Apache child process finally exits
  ## @param APR::Pool object
  ## @param Apache2::ServerRec server object
  ## This handler only adds an entry to the logs
  my ($p, $s) = @_;

  warn sprintf "[%s] Child exited: %d\n", time_str, $$ if $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;

  return OK;
}

1;
