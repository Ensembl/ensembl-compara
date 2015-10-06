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

use List::Util qw(first);

use parent qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my ($url, $params);

  my $presets = {
                  'journal'   => {'format' => 'png', 'extra' => '-c-2-s-2'},
                  'poster'    => {'format' => 'png', 'extra' =>'-c-2-s-5'},
                  'projector' => {'format' => 'png', 'extra' =>'-c-2-s-1.00'},
                  };
  my $format = $hub->param('image_format') || $presets->{$hub->param('format')}{'format'} 
                || $hub->param('format') || 'png';
  warn ">>> OUTPUTTING AS $format";
  ## Reset parameters to something that the image component will understand
  $hub->param('format', $format);

  ## Create component
  my ($component, $error) = $self->object->create_component;
  my $controller;

  if ($error) {
  }
  else {
    warn ">>> COMPONENT $component";
  }
  use Data::Dumper; warn Dumper($params);
  $self->ajax_redirect($hub->url($controller || (), $params), $controller ? (undef, undef, 'download') : ());
}

1;
