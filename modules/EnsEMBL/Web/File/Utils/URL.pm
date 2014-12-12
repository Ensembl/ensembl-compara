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

package EnsEMBL::Web::File::Utils::URL;

### Non-OO library for common functions required for handling remote files 
### Note that we have to use two different Perl modules here, owing to 
### limitations on support for FTP and proxied HTTPS

use strict;

use HTTP::Tiny;
use LWP::UserAgent;

use EnsEMBL::Web::File::Utils qw(check_compression);
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(chase_redirects file_exists read_file write_file delete_file get_filesize);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

use constant 'MAX_HIGHLIGHT_FILESIZE' => 1048576;  # (bytes) = 1Mb

sub chase_redirects {
### Deal with files "hidden" behind a URL-shortening service such as tinyurl
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param max_follow Integer - maximum number of redirects to follow
### @return url (String) or Hashref containing errors (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->location : $file;

  $args->{'max_follow'} = 10 unless defined $args->{'max_follow'};

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new( max_redirect => $args->{'max_follow'} );
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    return $response->is_success ? $response->request->uri->as_string
                                    : {'error' => [_get_lwp_useragent_error($response)]};
  }
  else {
    my %args = (
              'timeout'       => 10,
              'max_redirect'  => $args->{'max_follow'},
              );
    if ($args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $args{'http_proxy'}   = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $args{'https_proxy'}  = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%args);

    my $response = $http->request('HEAD', $url);
    if ($response->{'success'}) {
      return $response->{'url'};
    }
    else {
      return {'error' => [_get_http_tiny_error($response)]};
    }
  }
}

sub file_exists {
### Check if a file of this name exists
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         hub EnsEMBL::Web::Hub
### @return Hashref containing 'success' (1) or errors (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->location : $file;

  my ($success, $error);

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    unless ($response->is_success) {
      $error = _get_lwp_useragent_error($response);
    }
  }
  else {
    my %params = ('timeout'       => 10);
    if ($args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $params{'http_proxy'}   = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $params{'https_proxy'}  = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%params);

    my $response = $http->request('HEAD', $url);
    unless ($response->{'success'}) {
      $error = _get_http_tiny_error($response);
    }
  }

  if ($error) {
    return {'error' => [$error]};
  }
  else {
    return {'success' => 1};
  }
}

sub read_file {
### Get entire content of file
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         hub EnsEMBL::Web::Hub
###         compression String (optional) - compression type
### @return Hashref containing results (String) or errors (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->location : $file;

  my ($content, $error);

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->get($url);
    if ($response->is_success) {
      $content = $response->content;
    }
    else {
      $error = _get_lwp_useragent_error($response);
    }
  }
  else {
    my %params = ('timeout'       => 10);
    if ($args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $params{'http_proxy'}   = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $params{'https_proxy'}  = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%params);

    my $response = $http->request('GET', $url);
    if ($response->{'success'}) {
      $content = $response->{'content'};
    }
    else {
      $error = _get_http_tiny_error($response);
    }
  }

  if ($error) {
    return {'error' => [$error]};
  }
  else {
    my $compression = defined($args->{'compression'}) || check_compression($url);
    my $uncomp = $compression ? uncompress($content, $compression) : $content;
    return {'content' => $uncomp};
  }
}

sub write_file {
### Returns an error if caller tries to write to remote server!
### @param File - EnsEMBL::Web::File object or path to file (String)
### @return Hashref containing error (ArrayRef)
  my $file = shift;
  my $url = ref($file) ? $file->location : $file;
  warn "!!! Oops - tried to write to a remote server!";
  return {'error' => ["Cannot write to remote file $url. Function not supported"]};
}

sub delete_file {
### Returns an error if caller tries to delete file from remote server!
### @param File - EnsEMBL::Web::File object or path to file (String)
### @return Hashref containing error (ArrayRef)
  my $file = shift;
  my $url = ref($file) ? $file->location : $file;
  warn "!!! Oops - tried to delete file from a remote server!";
  return {'error' => ["Cannot delete remote file $url. Function not supported"]};
}

sub get_filesize {
### Get size of remote file 
### @param url - URL of file
### @param Args Hashref 
###         hub EnsEMBL::Web::Hub
###         compression String (optional) - compression type
### @return Hashref containing results (Integer - file size in bytes) or errors (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->location : $file;
  my ($size, $error);

  if ($url =~ /^ftp/) {
    ## TODO - support FTP!
    ## return arbitrary filesize as a stopgap!
    return {'filesize' => 1000};
  }
  else {
    my %params = ('timeout'       => 10);
    if ($args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $params{'http_proxy'}   = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $params{'https_proxy'}  = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%params);

    my $response = $http->request('HEAD', $url);
    if ($response->{'success'}) {
      $size = $response->{'headers'}{'Content-Length'} || 0;
    }
    else {
      $error = _get_http_tiny_error($response);
    }
  }

  if ($error) {
    return {'error' => [$error]};
  }
  else {
    return {'filesize' => $size};
  }
}

sub _get_lwp_useragent_error {
### Convert error responses from LWP::UserAgent into a user-friendly string
### @param response - HTTP::Response object
### @return String
  my $response = shift;

  return 'timeout'              unless $response->code;
  return $response->status_line if     $response->code >= 400;
  return;
}

sub _get_http_tiny_error {
### Convert error responses from HTTP::Tiny into a user-friendly string
### @param response HashRef 
### @return String
  my $response = shift;

  return 'timeout' unless $response->{'status'};
  if ($response->{'status'} >= 400) {
    return $response->{'status'}.': '.$response->{'reason'};
  }
  return;
}


1;

