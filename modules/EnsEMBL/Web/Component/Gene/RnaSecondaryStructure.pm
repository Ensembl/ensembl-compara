=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::RnaSecondaryStructure;

use strict;

use EnsEMBL::Web::Utils::FormatText qw(date_format);
use EnsEMBL::Web::Document::Image::R2R;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}


sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $html;

  my ($display_name) = $object->display_xref;

  my $image = EnsEMBL::Web::Document::Image::R2R->new($self->hub, $self, {});
  my $svg_path = $image->render($display_name);

  if ($svg_path) {
    my @path = split('/', $svg_path);
    my $filename = $path[-1];
    $html .= qq(<div class="component-tools tool_buttons "><a class="iexport" href="$svg_path" download="$filename" target="_blank">Download SVG</a></div>);
    $html .= qq(<object data="$svg_path" type="image/svg+xml"></object>);
  }
  $html .= sprintf '<h4>Key</h4><p><img src="%s/img/r2r_legend.png" /></p>', $self->static_server if $object->availability->{'has_2ndary_cons'};


  return $html;
}

1;
