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

package EnsEMBL::Web::Component::ViewNav;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->ajaxable(0);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $image_width = $self->image_width . 'px';
  my $r           = $hub->create_padded_region()->{'r'} || $hub->param('r');
  my $url         = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $r});

  return qq{
      <div class="navbar print_hide" style="width:$image_width">
        <a href="$url"><img src="/i/48/region_thumb.png" title="Go to Region in Detail for more options" style="border:1px solid #ccc;margin:0 16px;vertical-align:middle" /></a> Go to <a href="$url" class="no-visit">Region in Detail</a> for more tracks and navigation options (e.g. zooming)
      </div>};
}

1;
