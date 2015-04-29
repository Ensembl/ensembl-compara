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

package EnsEMBL::Web::Command::UserData::CheckRegions;

############# DEPRECATED #################
## This tool is no longer in use and will
## be removed in release 81
##########################################

## Checks the user's input and uploads/creates a file for processing

use strict;

use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $session = $hub->session;
  my $url     = $hub->species_path($hub->data_species) . '/UserData/';

  ## Get the data!
  my ($data, $content, $param);
  my ($method) = grep $hub->param($_), qw(file url text);
  if ($method) {
    my $response = $self->upload($method, 'coords');
    $data = $session->get_data(code => $response->{'code'});
    my $file = EnsEMBL::Web::TmpFile::Text->new(filename => $data->{'filename'}, extension => $data->{'extension'});
    if ($file) {
      $content = $file->retrieve;
      $param->{'code'} = $data->{'code'};
      $param->{'name'} = $hub->param('name');
    }
    else {
      $param->{'error_code'} = 'load_file';
    }
  }

  ## Now limit by region length and feature type
  my %features = map {$_ => 1} ($hub->param('include'));
  my $limit = ($features{'v'} || $features{'r'}) ? 1000000 : 5000000;

  if ($content) {
    my @slices;
    my @regions = split(/\r?\n/, $content);
    foreach my $region (@regions) {
      my ($chr, $start, $end) = split(':|-|\.\.', $region);
      push @slices, {'chr' => $chr, 'start' => $start, 'end' => $end};
    }
    ## Calculate total sequence length
    my $total_length;
    foreach my $slice (@slices) {
      my $l = $slice->{'start'} - $slice->{'end'};
      $total_length += abs($l);
    }
    if ($total_length > $limit) {
      $param->{'error_code'} = 'location_toolarge';
    }
    else {
      ## Pass checkbox options as a single string (same format used by API script)
      $param->{'include'}       = join('', $hub->param('include'));
      $param->{'output_format'} = $data->{'format'};
    }

  }
  else {
    ## No identifiable regions
    $param->{'error_code'} = 'location_unknown';
  }

  if ($param->{'error_code'}) {
    $param->{'action'} = 'RegionReportOutput';
    $session->purge_data('code' => $param->{'code'});
    $self->ajax_redirect($hub->url($param));
  }
  else {
    $url .= 'RunRegionTool';
    $self->ajax_redirect($url, $param);
  }
    
}

1;
