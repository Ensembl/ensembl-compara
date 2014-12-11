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

package EnsEMBL::Web::Tools::Misc;

## Just a bunch of useful tools
use strict;

use LWP::UserAgent;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::CompressionSupport;

use base qw(Exporter);

use constant 'MAX_HIGHLIGHT_FILESIZE' => 1048576;  # (bytes) = 1Mb

our @EXPORT = our @EXPORT_OK = qw(pretty_date get_url_content get_url_filesize style_by_filesize champion);

sub pretty_date {
  my $timestamp = shift;
  my @date = localtime($timestamp);
  my @days = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  return $days[$date[6]].' '.$date[3].' '.$months[$date[4]].', '.($date[5] + 1900);
}

# Computes given score on each member of list and returns member with highest
sub champion(&@) {
  my $f = shift;
  my ($champion,$best);
  foreach(@_) {
    my $v = $f->($_);
    if(!defined $best or $best < $v) {
      $champion = $_;
      $best = $v;
    }
  }
  return $champion;
}

sub get_url_content {
######## DEPRECATED ################
warn "DEPRECATED METHOD 'get_url_content' - please switch to using EnsEMBL::Web::File::Utils::URL::read_file. This method will be removed in release 80.";
####################################
  my $url   = shift;
  my $proxy = shift || $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;

  my $ua = LWP::UserAgent->new;
     $ua->timeout( 10 );
     $ua->proxy( [qw(http https)], $proxy ) if $proxy;

  my $request  = HTTP::Request->new( 'GET', $url );
     $request->header('Cache-control' => 'no-cache');
     $request->header('Pragma'        => 'no-cache');

  my $response = $ua->request( $request );
  my $error    = _get_http_error( $response );
  if ($error) {
    return { 'error'   => $error };
  }
  else {
    my $content  = $response->content;
    EnsEMBL::Web::CompressionSupport::uncomp( \$content );
    return { 'content' => $content }
  }
}

sub get_url_filesize {
######## DEPRECATED ################
warn "DEPRECATED METHOD 'get_url_filesize' - please switch to using EnsEMBL::Web::File::Utils::URL::get_filesize. This method will be removed in release 80.";
####################################
## Returns the size of a file in bytes, or an error code if the request fails
## TODO - needs changing to get just the first line or so of the file before
## trying to fetch the rest, in case we are dealing with a huge file format like BAM!
  my $url   = shift;
  my $proxy = shift || $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WWW_PROXY;

  my $feedback = {};

  ## TODO - handle FTP as well as HTTP
  if ($url =~ /^ftp:\/\//i) {
    ## return arbitrary filesize as a stopgap!
    return {'filesize' => 1000};
  }

  my $ua = LWP::UserAgent->new;
     $ua->timeout(10);
     $ua->proxy([qw(http https)], $proxy) if $proxy;

  my $request = HTTP::Request->new( 'GET', $url );
     $request->header('Cache-control' => 'no-cache');
     $request->header('Pragma'        => 'no-cache');

  my $response = $ua->request($request);
  my $error = _get_http_error($response);

  return { 'error' => $error } if $error;

  # Get the size of the file if possible
  my $size = 0;
  if ($response->header('Content-Length')) {
    $size = $response->header('Content-Length');
  }
  else {
    #if ($content) {
    #  $size = length(EnsEMBL::Web::CompressionSupport::uncomp( \$content ));
    #}
    $size = 1000;
  }
  return {'filesize' => $size};
}

sub _get_http_error {
  my $response = shift;

  return 'timeout'              unless $response->code;
  return $response->status_line if     $response->code >= 400;
  return 'mime'                 if     $response->content_type =~ /HTML/i;
  return;
}


sub style_by_filesize {
  my $filesize     = shift || 0;
  my $max_filesize = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->MAX_HIGHLIGHT_FILESIZE || MAX_HIGHLIGHT_FILESIZE;
  return $filesize > $max_filesize ? 'density_line' : 'highlight_lharrow';
}

1;
