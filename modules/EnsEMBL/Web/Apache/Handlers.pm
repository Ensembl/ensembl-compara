=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use SiteDefs;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::SpeciesDefs;

use EnsEMBL::Web::Apache::DasHandler;
use EnsEMBL::Web::Apache::SSI;
use EnsEMBL::Web::Apache::SpeciesHandler;

use Preload;

our $species_defs = EnsEMBL::Web::SpeciesDefs->new;

sub get_rewritten_uri {
  ## Recieves the current URI and returns a new URI in case it has to be rewritten
  ## The same request itself is handled according to the rewritten URI instead of making an external redirect request
  ## @param URI string
  ## @return URI string if modified, undef otherwise
  ## In a plugin, use this function with PREV to add plugin specific rules
}

sub get_redirect_uri {
  ## Recieves the current URI and returns a new URI in case an external HTTP redirect has to be performed on that
  ## @param URI string
  ## @return URI string if redirection required, undef otherwise
  ## In a plugin, use this function with PREV to add plugin specific rules
  my $uri = shift;

  ## Redirect to contact form
  if ($uri =~ m|^/contact\?$|) {
    return '/Help/Contact';
  }

  ## Fix URL for V/SV Explore pages
  if ($uri =~ m|^/Variation/Summary/|) {
    return $uri =~ s/Summary/Explore/r;
  }

  ## Trackhub short URL
  if ($uri =~ m|^/trackhub\?|i) {
    return $uri = s/trackhub/UserData\/TrackHubRedirect/r;
  }

  ## For stable id URL (eg. /id/ENSG000000nnnnnn) or malformed Gene URL with g param
  if ($uri =~ m|^/id/(.+)|i || ($uri =~ m|^/Gene\W| && $uri =~ /[\&\;\?]{1}g=([^\&\;]+)/)) {
    return stable_id_redirect_uri($1);
  }

  return undef;
}

sub stable_id_redirect_uri {
  ## Constructs complete URI according to a given stable id
  ## @param Stable ID string
  my $stable_id = shift;

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

    $uri = sprintf '/%s/', $species ? ($species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP') || {})->{lc $species} || $species : 'Multi';

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
      $uri .= "psychic?q=$stable_id";
    }
  }

  return $uri || "/Multi/psychic?q=$stable_id";
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

sub get_sub_handler {
  ## Finds out the sub handler that should handle this request
  ## @param Apache2::RequestRec request object
  ## @param Species name (string)
  ## @param Arrayref of path segments
  ## @return List containing handler (possibly undef if no sub handler maps to this requests), species (possibly modified) and arrayref of path segments (possibly modified)
  my ($r, $species, $path_seg) = @_;

  my $handler;

  # Try DasHandler if first segment of path is 'das'
  if (!$species && $path_seg->[0] eq 'das') {

    shift @$path_seg; # remove 'das'

    ($species)  = split '.', $path_seg->[0] // '';
    $handler    = 'EnsEMBL::Web::Apache::DasHandler';

  # Try SpeciesHandler in all other cases if species is present or the file path is not an explicit .html path
  } elsif ($species || $path_seg->[-1] !~ /\.html$/) {

    $species  ||= 'Multi';
    $species    = 'Multi' if $species eq 'common';
    $handler    = 'EnsEMBL::Web::Apache::SpeciesHandler';

  # Finally try the SSI handler
  } else {
    $handler    = 'EnsEMBL::Web::Apache::SSI';
  }

  return ($handler, $species, $path_seg);
}

sub http_redirect {
  ## Perform an http redirect
  ## @param Apache2::RequestRec request object
  ## @param URI string to redirect to
  ## @return HTTP_MOVED_PERMANENTLY
  my ($r, $redirect_uri) = @_;
  $r->uri($redirect_uri);
  $r->headers_out->add('Location' => $r->uri);
  $r->child_terminate; # TODO really needed?

  return HTTP_MOVED_PERMANENTLY;
}

sub time_str {
  ## @return Printable time string
  return strftime("%a %b %d %H:%M:%S %Y", shift || localtime);
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
  ## This handler only adds an entry to the logs
  warn sprintf "[%s] Child initialised: %d\n", time_str, $$ if $SiteDefs::ENSEMBL_DEBUG_FLAGS && $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;

  return OK;
}

sub postReadRequestHandler {
  ## This handler gets called immediately after the request has been read and HTTP headers were parsed
  ## @param Apache2::RequestRec request object
  my $r = shift;

  return OK if $r->unparsed_uri eq '*';

  # VOID request to populate %ENV
  $r->subprocess_env;

  # save request start time for logs
  $r->subprocess_env('LOG_REQUEST_START', sprintf('%0.6f', time));

  # run any plugged-in code
  request_start_hook($r);

  return OK;
}

sub transHandler {
  ## This handler gets called to perform the manipulation of a request's URI
  ## @param Apache2::RequestRec request object
  my $r   = shift;
  my $uri = $r->unparsed_uri;

  return DECLINED if $uri eq '*';

  # apply any uri rewrite rules
  if (my $modified = get_rewritten_uri($uri)) {
    $r->parse_uri($modified);
  }

  # save raw uri for logs
  $r->subprocess_env('LOG_REQUEST_URI', $r->unparsed_uri);

  return DECLINED;
}

sub handler {
  ## This is the main handler that gets called to generate a response for the given request
  ## @param Apache2::RequestRec request object
  ## @return One of the Apache2::Const common/http codes
  my $r   = shift;
  my $uri = $r->unparsed_uri;

  # handle any redirects
  if (my $redirect = get_redirect_uri($uri)) {
    return http_redirect($r, $redirect);
  }

  # populate subprocess_env with species, path and query or perform a redirect to a rectified url
  if (my $redirect = parse_ensembl_uri($r)) {
    return http_redirect($r, $redirect);
  }

  my $species   = $r->subprocess_env('ENSEMBL_SPECIES');
  my $path      = $r->subprocess_env('ENSEMBL_PATH');
  my $query     = $r->subprocess_env('ENSEMBL_QUERY');
  my $path_seg  = [ grep { $_ ne '' } split '/', $path ];

  # other species-like path segments
  if (!$species && grep /$path_seg->[0]/, qw(Multi common)) {
    $species = shift @$path_seg;
  }

  # find the appropriate handler according to species and path
  (my $handler, $species, $path_seg) = get_sub_handler($r, $species, $path_seg);

  # there is a possibility ENSEMBL_SPECIES and ENSEMBL_PATH need to be updated
  $r->subprocess_env('ENSEMBL_SPECIES', $species);
  $r->subprocess_env('ENSEMBL_PATH',    '/'.join('/', @$path_seg));

  # delegate request to the required handler and get the response status code
  my $response_code = $handler ? $handler->can('handler')->($r, $species_defs) : undef;

  # check for any redirects requested by the code
  if (my $redirect = $r->subprocess_env('ENSEMBL_REDIRECT')) {
    return http_redirect($r, $redirect);
  }

  # give up if no response code was set by any of the handlers
  return DECLINED unless defined $response_code;

  # kill off the process when it grows too large
  $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler) if $response_code == OK;

  return $response_code;
}

sub logHandler {
  ## This handler gets called once the response is genetated, irrespective of the return type of the previous handler.
  ## @param Apache2::RequestRec request object
  my $r = shift;
  my $t = time;

  return DECLINED if $r->unparsed_uri eq '*';

  # more vars for logs
  $r->subprocess_env('LOG_REQUEST_END',   sprintf('%0.6f', $t));
  $r->subprocess_env('LOG_REQUEST_TIME',  sprintf('%0.6f', $t - $r->subprocess_env('LOG_REQUEST_START')));

  return DECLINED;
}

sub cleanupHandler {
  ## This handler gets called immediately after the request has been served (the client went away) and before the request object is destroyed.
  ## Any time consuming logging process should be done in this handler since the request connection has actually been closed by now.
  ## @param Apache2::RequestRec request object
  my $r = shift;

  return OK if $r->unparsed_uri eq '*';

  # run any plugged-in code
  request_end_hook($r);

  my $start_time = $r->subprocess_env('LOG_REQUEST_START');
  my $time_taken = $r->subprocess_env('LOG_REQUEST_TIME');

  if ($time_taken >= $SiteDefs::ENSEMBL_LONGPROCESS_MINTIME) {

    my $uri    = $r->subprocess_env('LOG_REQUEST_URI');
    my ($size) = $Apache2::SizeLimit::HOW_BIG_IS_IT ? $Apache2::SizeLimit::HOW_BIG_IS_IT->() : Apache2::SizeLimit->_check_size;

    if ($SiteDefs::ENSEMBL_DEBUG_FLAGS && $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS) {
      my @X = localtime($start_time);

      warn sprintf(
        "LONG PROCESS: %12s DT:  %04d-%02d-%02d %02d:%02d:%02d Time: %10s Size: %10s\nLONG PROCESS: %12s REQ: %s\nLONG PROCESS: %12s IP:  %s  UA: %s\n",
        $$, $X[5]+1900, $X[4]+1, $X[3], $X[2], $X[1], $X[0], $time_taken, $size,
        $$, $uri,
        $$, $r->subprocess_env('HTTP_X_FORWARDED_FOR'), $r->headers_in->{'User-Agent'}
      );
    }
  }

  return OK;
}

sub childExitHandler {
  ## This handler gets called when the Apache child process finally exits
  ## @param APR::Pool object
  ## @param Apache2::ServerRec server object
  ## This handler only adds an entry to the logs
  my ($p, $s) = @_;

  warn sprintf "[%s] Child exited: %d\n", time_str, $$ if $SiteDefs::ENSEMBL_DEBUG_FLAGS && $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;

  return OK;
}

1;
