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

package EnsEMBL::Web::Command::UserData::AddFile;

## Attaches or uploads a file and does some basic checks on the format

use strict;

use List::Util qw(first);

use EnsEMBL::Web::File::AttachedFormat;
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects file_exists);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return $self->set_format if $hub->function eq 'set_format';
 
  my ($method)    = first { $hub->param($_) } qw(file text);
  my $format_name = $hub->param('format');
  my $url_params  = {};
  my $new_action  = '';
  my $attach      = 0;
  my $url;

  if ($method eq 'text' && $hub->param('text') =~ /^\s*(http|ftp)/) {
    ## Attach the file from the remote URL
    $url = $hub->param('text'); 
    $url =~ s/(^\s+|\s+$)//g; # Trim leading and trailing whitespace

    ## Move URL into appropriate parameter, because we need to distinguish it from pasted data
    $hub->param('url', $url);
    $hub->param('text', '');
    $method = 'url';

    ## Set 'attach' flag if we can't upload it
    my $format_info = $hub->species_defs->multi_val('DATA_FORMAT_INFO');
    if ($format_info->{lc($format_name)}{'remote'}) {
      $attach = 1;
    } 
    elsif (uc($format_name) eq 'VCF' || uc($format_name) eq 'PAIRWISE') {
      ## Is this an indexed file? Check formats that could be either
      my $tabix_url   = $url.'.tbi';
      $attach = $self->check_for_index($tabix_url);
    } 
  }

  if ($attach) {
    ## Is this file already attached?
    ($new_action, $url_params) = $self->check_attachment($url);

    if ($new_action) {
      $url_params->{'action'} = $new_action;
    }
    else {
      my %args = ('hub' => $self->hub, 'format' => $format_name, 'url' => $url, 'track_line' => $self->hub->param('trackline'));
      my $attachable;

      if ($attach eq 'error') {
        ## Something went wrong with check
        $url_params->{'restart'} = 1;
      }
      else {
        my $package = 'EnsEMBL::Web::File::AttachedFormat::' . uc $format_name;

        if ($self->dynamic_use($package)) {
          $attachable = $package->new(%args);
        } 
        else {
          $attachable = EnsEMBL::Web::File::AttachedFormat->new(%args);
        }
        my $filename  = [split '/', $url]->[-1];
        ($new_action, $url_params) = $self->attach($attachable, $filename);
        $url_params->{'action'} = $new_action;
      }
    }
  }
  else {
    ## Upload the data
    $url_params = $self->upload($method, $format_name);
    $url_params->{ __clear} = 1;
    $url_params->{'action'} = 'UploadFeedback';
  }

  if ($url_params->{'restart'}) {
    $url_params->{'action'} = 'SelectFile';
  }

  return $self->ajax_redirect($self->hub->url($url_params));
}

sub check_for_index {
  my ($self, $url) = @_;

  my $args = {'hub' => $self->hub, 'nice' => 1};
  my $ok_url = chase_redirects($url, $args);
  my ($index_exists, $error);

  if (ref($ok_url) eq 'HASH') {
    $error = $ok_url->{'error'}[0];
  }
  else {
    my $check = file_exists($ok_url, $args);    
    if ($check->{'error'}) {
      $error = $check->{'error'}[0];
    }
    else {
      $index_exists = $check->{'success'};
    }
  }
  
  if ($error) {
    warn "!!! URL ERROR: $error";
    return 'error';
  }
  else {
    return $index_exists;
  }
}

sub set_format {
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $code    = $hub->param('code');
  my $format  = $hub->param('format');
  
  $session->set_data(%{$session->get_data(code => $code)}, format => $format) if $format;
  
  $self->ajax_redirect($hub->url({
    action   => $format ? 'UploadFeedback' : 'MoreInput',
    function => undef,
    format   => $format,
    code     => $code
  }));
}

1;
