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

  ## Set contrast flag
  my $export    = $format;
  my $contrast  = $hub->param('contrast') || $presets->{$hub->param('format')}{'contrast'};
  if ($contrast) {
    $export .= sprintf('-c-%s', $contrast);
  }

  ## Save size parameters (because we reset format in next block)
  my $resize = $hub->param('image_format') ? $hub->param('resize') : $presets->{$hub->param('format')}{'size'};
  my $current_width = $ENV{'ENSEMBL_IMAGE_WIDTH'};

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

  unless ($error) {
    ## Resize image as necessary
    if ($resize && $resize != $current_width) {
      my $type        = $hub->param('data_type');
      my $view_config = $component->view_config($type);
      if ($view_config) {
        my $ic_name       = $view_config->image_config;
        my $image_config  = $hub->get_imageconfig($ic_name);
        $image_config->image_width($resize) if $image_config;
      }
    }

    $component->content;
    my $path = $hub->param('file');
    $controller = 'Download';

    $params->{'filename'}       = $filename;
    $params->{'format'}         = $format;
    $params->{'file'}           = $path;
    $params->{'__clear'}        = 1;

    $self->ajax_redirect($hub->url('Download', $params), undef, undef, 'download');
  }
}

1;
