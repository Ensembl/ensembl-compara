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

package EnsEMBL::Web::File::Utils::URL;

### Non-OO library for common functions required for handling remote files 
### Note that we have to use two different Perl modules here, owing to 
### limitations on support for FTP and proxied HTTPS

### File access methods have two modes: "nice" mode is most suitable for
### web interfaces, and returns a hashref containing either the raw content
### or a user-friendly error message (no exceptions are thrown). "Non-nice" 
### or raw mode returns 0/1 for failure/success or the expected raw data, 
### and optionally throws exceptions.

### IMPORTANT: You must pass a reference to the Hub to all methods, so that they
### can access site-wide parameters such as proxies

use strict;

use HTTP::Tiny;
use LWP::UserAgent;

use EnsEMBL::Web::File::Utils qw(get_compression uncompress);
use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(chase_redirects file_exists read_file write_file delete_file get_filesize);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

use constant 'MAX_HIGHLIGHT_FILESIZE' => 1048576;  # (bytes) = 1Mb

sub chase_redirects {
### Deal with files "hidden" behind a URL-shortening service such as tinyurl
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param args Hashref
###                     hub EnsEMBL::Web::Hub
###                     max_follow (optional) Integer - maximum number of redirects to follow
### @return url (String) or Hashref containing errors (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->read_location : $file;

  $args->{'max_follow'} = 10 unless defined $args->{'max_follow'};

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new( max_redirect => $args->{'max_follow'} );
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    if ($response->is_success) {
      return $response->request->uri->as_string;
    }
    else {
      my $error = _get_lwp_useragent_error($response);
      if ($error =~ /405/) {
        ## Try a GET request, if the server is misconfigured
        $response = $ua->get($url);
        if ($response->is_success) {
          return $response->request->uri->as_string;
        }
        else {
          return {'error' => [_get_lwp_useragent_error($response)]};
        }
      }
      else {
        return {'error' => [$error]};
      }
    }
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
      my $error = _get_http_tiny_error($response);
      if ($error =~ /405/) {
        ## Try a GET request, if the server is misconfigured
        $response = $http->request('GET', $url);
        if ($response->{'success'}) {
          return $response->{'url'};
        }
        else {
          return {'error' => [_get_http_tiny_error($response)]};
        }
      }
      else {
        return {'error' => [$error]};
      }
    }
  }
}

sub file_exists {
### Check if a file of this name exists
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         hub EnsEMBL::Web::Hub
###         nice (optional) Boolean - see introduction
###         no_exception (optional) Boolean
### @return Hashref (nice mode) or Boolean 
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->absolute_read_path : $file;

  my ($success, $error);

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    unless ($response->is_success) {
      $error = _get_lwp_useragent_error($response);
      if ($error =~ /405/) {
        ## Try a GET request, if the server is misconfigured
        $error = undef;
        $response = $ua->get($url);
        unless ($response->is_success) {
          $error = _get_lwp_useragent_error($response);
        }  
      }
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
    unless ($response->{'success'}) {
      $error = _get_http_tiny_error($response);
      if ($error =~ /405/) {
        ## Try a GET request, if the server is misconfigured
        $error = undef;
        $response = $http->request('GET', $url);
        unless ($response->{'success'}) {
          $error = _get_http_tiny_error($response);
        }  
      }
    }
  }

  if ($args->{'nice'}) {
    return $error ? {'error' => [$error]} : {'success' => 1};
  }
  else {
    if ($error) {
      throw exception('URLException', "File $url could not be found: $error") unless $args->{'no_exception'};
      return 0;
    }
    else {
      return 1;
    }
  }
}

sub read_file {
### Get entire content of file
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         hub EnsEMBL::Web::Hub
###         nice (optional) Boolean - see introduction
###         compression String (optional) - compression type
### @return Hashref (in nice mode) or String - contents of file
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->absolute_read_path : $file;

  my ($content, $error);

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->get($url, %{$args->{'headers'}});
    if ($response->is_success) {
      $content = $response->content;
    }
    else {
      $error = _get_lwp_useragent_error($response);
      warn "!!! ERROR FETCHING FILE $url: $error";
    }
  }
  else {
    my %params = ('timeout'       => 10);
    if ($args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $params{'http_proxy'}   = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $params{'https_proxy'}  = $args->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%params);

    my @http_params = ('GET', $url);
    push @http_params, $args->{'headers'} if $args->{'headers'};
    my $response = $http->request(@http_params);
    if ($response->{'success'}) {
      $content = $response->{'content'};
    }
    else {
      $error = _get_http_tiny_error($response);
      warn "!!! ERROR FETCHING FILE $url: $error";
    }
  }

  if ($error) {
    if ($args->{'nice'}) {
      return {'error' => [$error]};
    }
    else {
      throw exception('URLException', "File $url could not be read: $error") unless $args->{'no_exception'};
      return 0;
    }
  }
  else {
    my $compression = defined($args->{'compression'}) || get_compression($url);
    if ($compression) {
      uncompress(\$content, $compression);
    }
    if ($args->{'nice'}) {
      return {'content' => $content};
    }
    else {
      return $content;
    }
  }
}

sub write_file {
### Returns an error if caller tries to write to remote server!
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         nice (optional) Boolean - see introduction
### @return Zero (nice mode) or Hashref containing error
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->write_url : $file;
  warn "!!! Oops - tried to write to a remote server!";
  if ($args->{'nice'}) {
    return {'error' => ["Cannot write to remote file $url. Function not supported"]};
  }
  else {
    throw exception('URLException', "Writing to remote files not permitted!") unless $args->{'no_exception'};
    return 0;
  }
}

sub delete_file {
### Returns an error if caller tries to delete file from remote server!
### @param File - EnsEMBL::Web::File object or path to file (String)
### @param Args Hashref 
###         nice (optional) Boolean - see introduction
### @return Zero (nice mode) or Hashref containing error (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->write_url : $file;
  warn "!!! Oops - tried to delete file from a remote server!";
  if ($args->{'nice'}) {
    return {'error' => ["Cannot delete remote file $url. Function not supported"]};
  }
  else {
    throw exception('URLException', "Deleting remote files not permitted!") unless $args->{'no_exception'};
    return 0;
  }
}

sub get_headers {
### Get one or all headers from a remote file 
### @param url - URL of file
### @param Args Hashref 
###         header (optional) String - name of header
###         hub EnsEMBL::Web::Hub
###         nice (optional) Boolean - see introduction
###         compression String (optional) - compression type
### @return Hashref containing results (single header or hashref of headers) or errors (ArrayRef)
  my ($file, $args) = @_;
  my $url = ref($file) ? $file->absolute_read_path : $file;
  my ($all_headers, $result, $error);

  if ($url =~ /^ftp/) {
    ## TODO - support FTP properly!
    return {'Content-Type' => 1};
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
      $all_headers = $response->{'headers'};
    }
    else {
      $error = _get_http_tiny_error($response);
    }
  }

  $result = $args->{'header'} ? $all_headers->{$args->{'header'}} : $all_headers;

  if ($args->{'nice'}) {
    if ($error) {
      if ($error =~ /405/) {
        ## Some servers don't accept header requests, which is annoying but not fatal
        $error = 'denied';
      }
      return {'error' => [$error]};
    }
    else {
      return {'headers' => $result};
    }
  }
  else {
    if ($error) {
      throw exception('URLException', "Could not get headers.") unless $args->{'no_exception'};
      return 0;
    }
    else {
      return $result;
    }
  }
}

sub get_filesize {
### Get size of remote file 
### @param url - URL of file
### @param Args Hashref 
###         hub EnsEMBL::Web::Hub
###         nice (optional) Boolean - see introduction
###         compression String (optional) - compression type
### @return Hashref containing results (Integer - file size in bytes) or errors (ArrayRef)
  my ($file, $args) = @_;
  $args->{'header'} = 'Content-Length';
  return get_headers($file, $args);
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

