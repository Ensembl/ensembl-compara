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

use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(chase_redirects file_exists get_filesize read_file);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

use constant 'MAX_HIGHLIGHT_FILESIZE' => 1048576;  # (bytes) = 1Mb

sub chase_redirects {
### Deal with files "hidden" behind a URL-shortening service such as tinyurl
### @param url String - initial URL supplied by the interface
### @param max_follow Integer - maximum number of redirects to follow
### @return url String - the actual URL of the file
  my ($self, $url, $max_follow) = @_;

  $max_follow = 10 unless defined $max_follow;

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new( max_redirect => $max_follow );
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    return $response->is_success ? $response->request->uri->as_string
                                    : {'error' => [_get_lwp_useragent_error($response)]};
  }
  else {
    my %args = (
              'timeout'       => 10,
              'max_redirect'  => $max_follow,
              );
    if ($self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $args{'http_proxy'}   = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $args{'https_proxy'}  = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
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
### @param url - URL of file
### @return Boolean
  my $url = shift;
  my ($success, $error);

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    unless ($response->is_success) {
      $error = _get_lwp_useragent_error($response);
    }
  }
  else {
    my %args = (
              'timeout'       => 10,
              );
    if ($self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $args{'http_proxy'}   = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $args{'https_proxy'}  = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%args);

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
}

sub read_file {
### Get entire content of file
### @param url - URL of file
### @param Args (optional) Hashref 
###         compression String - compression type
### @return String (entire file)
  my ($url, $args) = @_;
  my ($content, $error);

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->get($url);
    if ($response->is_success) {
      $content = $response->content;
    }
    else {
      $error = _get_lwp_useragent_error($response);
    }
  }
  else {
    my %args = (
              'timeout'       => 10,
              );
    if ($self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $args{'http_proxy'}   = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $args{'https_proxy'}  = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%args);

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

sub get_filesize {
### Get size of remote file 
### @param url - URL of file
### @param Args (optional) Hashref 
###         compression String - compression type
### @return Integer - file size in bytes
  my ($url, $args) = @_;
  my ($size, $error);

  if ($url =~ /^ftp/) {
    ## TODO - support FTP!
    ## return arbitrary filesize as a stopgap!
    return {'filesize' => 1000};
  }
  else {
    my %args = (
              'timeout'       => 10,
              );
    if ($self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $args{'http_proxy'}   = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $args{'https_proxy'}  = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%args);

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

