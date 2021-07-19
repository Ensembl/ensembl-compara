=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Command::ImageExport::ImageOutput;

## Output an image for downloading

use strict;
use warnings;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::File::Utils qw(sanitise_path);

use parent qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my ($url, $params);

  my $presets = EnsEMBL::Web::Constants::IMAGE_EXPORT_PRESETS;

  my $format = $hub->param('image_format') || $presets->{$hub->param('format')}{'format'} 
                || $hub->param('format') || 'png';
  my $export = $format;

  ## Set flags for scale and contrast
  my %flags = ('contrast' => 'c', 'scale' => 's');
  foreach (sort keys %flags) {
    my $flag =  $hub->param($_) || $presets->{$hub->param('format')}{$_};
    if ($flag) {
      $export .= sprintf('-%s-%s', $flags{$_}, $flag);
    }
  }

  ## Save size parameters (because we reset format in next block)
  my $resize = $hub->param('image_format') ? $hub->param('resize') : $presets->{$hub->param('format')}{'size'};
  my $current_width = $hub->image_width;

  ## Reset parameters to something that the image component will understand
  $hub->param('format', $format);
  $hub->param('export', $export);
  $hub->param('download', 1);

  ## Clean up user-provided filename
  my $filename = $hub->param('filename'); 
  $filename = sanitise_path($filename);
  $hub->param('filename', $filename);

  ## Create component
  my ($component, $error) = $self->object->create_component;
  my $controller;

  # another terrible hack to deal with the stupid caching mechanism of view config object in hub->viewcofig and use it for hub->param calls!
  $hub->get_viewconfig({component => $component->id, type => $hub->param('data_type'), cache => 1}) if $hub->param('data_type');

  if ($error) {
    warn ">>> ERROR CREATING COMPONENT: $error";
  }
  else {
    ## Resize image as necessary
    if ($resize && $resize != $current_width) {
      $hub->param('image_width', $resize);
    }

    $component->content;
    my $path = $hub->param('file');
    $path =~ s/-/_/g;
    $controller = 'Download';

    $params->{'filename'}       = $filename;
    $params->{'format'}         = $format;
    $params->{'file'}           = $path;
    $params->{'extra'}          = $hub->param('extra');
    $params->{'__clear'}        = 1;

    $self->ajax_redirect($hub->url('Download', $params), undef, undef, 'download');
  }
}

1;
