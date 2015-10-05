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

package EnsEMBL::Web::Command::ImageExport::Output;

### Redirects to the view's standard image export mode

use strict;
use warnings;

use List::Util qw(first);

use parent qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my ($url, $params);

  my $format = $hub->param('format') || 'png';

  if ($hub->param('next')) {
    ## User wants to choose which tracks are output
    $url = hub->url({'action' => 'SelectTracks'});
    foreach ($hub->param) {
      $params->{$_} = $hub->param($_);
    }
  }
  elsif ($format eq 'text') {
    ## Convert all selected tracks to a text-based file format
  }
  else {
    ## Output the actual image
    $url = sprintf('/%s/Component/%s/Web/%s', $hub->species_path, $hub->param('data_type'), $hub->param('component'));

    my $canned = {
                  'journal'   => '-c-2-s-2',
                  'poster'    => '-c-2-s-5',
                  'projector' => '-c-2-s-1.00',
                  };
    my ($extra) = first { $hub->param($_) } qw(journal projector poster);
    $format .= $extra if $extra;
 
    $params = {
                'export'    => $format,
                'download'  => $hub->param('download') || 0,
                };
  }
  $self->ajax_redirect($url, $params); 
}

1;
