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

package EnsEMBL::Web::Command::UserData::AddFile;

## Attaches or uploads a file and does some basic checks on the format

use strict;
use warnings;

use List::Util qw(first);

use EnsEMBL::Web::File::AttachedFormat;
use EnsEMBL::Web::Utils::UserData qw(check_attachment);
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects file_exists);
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use parent qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  my $url_params = $self->upload_or_attach;

  return $self->ajax_redirect($self->hub->url($url_params));
}

sub upload_or_attach {
  my ($self, $renderer) = @_;
  my $hub  = $self->hub;

  my ($method)      = first { $hub->param($_) } qw(file text);
  my $format_name   = $hub->param('format');
  my $species_defs  = $hub->species_defs;
  my $url_params    = {};
  my $new_action    = '';
  my $attach        = 0;
  my $index_err     = 0; # is on if index is required, but is missiing
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
    my $format_info = $species_defs->multi_val('DATA_FORMAT_INFO');
    if ($format_info->{lc($format_name)}{'remote'}) {
      $attach = 1;
    }
    elsif (uc($format_name) eq 'VCF' || uc($format_name) eq 'PAIRWISE') {
      ## Is this an indexed file? Check formats that could be either
      $index_err = !$self->check_for_index($url);
      $attach = !$index_err;
    }
  }

  if ($attach) {
    ## Is this file already attached?
    ($new_action, $url_params) = check_attachment($hub, $url);

    if ($new_action) {
      $url_params->{'action'} = $new_action;
    }
    else {
      my %args = ('hub' => $hub, 'format' => $format_name, 'url' => $url, 'track_line' => $hub->param('trackline') || '', 'registry' => $hub->param('registry') || 0);
      my $attachable;

      if ($attach eq 'error') {
        ## Something went wrong with check
        $url_params->{'restart'} = 1;
      }
      else {
        my $package = 'EnsEMBL::Web::File::AttachedFormat::' . uc $format_name;

        if (dynamic_require($package, 1)) {
          $attachable = $package->new(%args);
        }
        else {
          $attachable = EnsEMBL::Web::File::AttachedFormat->new(%args);
        }
        my $filename  = [split '/', $url]->[-1];
        ($new_action, $url_params) = $self->attach($attachable, $filename, $renderer);
        $url_params->{'action'} = $new_action;
      }
    }
    $url_params->{'record_type'} = 'url';
  }
  else {
    ## Upload the data
    $url_params = $self->upload($method, $format_name, $renderer, $index_err ? $species_defs->UPLOAD_SIZELIMIT_WITHOUT_INDEX : 0);
    $url_params->{__clear}        = 1;
    $url_params->{'record_type'}  = 'upload';
  }

  if ($url_params->{'restart'}) {
    $url_params->{'action'} = 'SelectFile';
  }

  return $url_params;
}

sub check_for_index {
  my ($self, $input_url) = @_;

  my $args = {'hub' => $self->hub, 'nice' => 1};
  my ($index_exists, $error);
  my @exts = qw(tbi csi);

  foreach my $ext (@exts) {
    my $url = $input_url.'.'.$ext;
    my $ok_url = chase_redirects($url, $args);
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
    if ($index_exists) {
      $error = 0;
      last;
    } 
  }

  if ($error) {
    $self->hub->session->set_record_data({
      type     => 'message',
      code     => 'userdata_upload',
      message  => "Your file has no tabix index, so we have attempted to upload it. If the upload fails (e.g. your file is too large), please provide a tabix index and try again.",
      function => '_warning'
    });
  }
  return $index_exists;
}

1;
