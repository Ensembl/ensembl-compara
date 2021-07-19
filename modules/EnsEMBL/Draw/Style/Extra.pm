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

package EnsEMBL::Draw::Style::Extra;

use strict;
use warnings;

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
  warn "There are no default glyphs in Extra classes, so you need to call your chosen method explicitly";
}

sub get_text_dimensions {
  my ($self, $text, $font) = @_;

  my %font_details = $font ? %$font : EnsEMBL::Draw::Utils::Text::get_font_details($self->image_config,'innertext', 1);
  my @text = EnsEMBL::Draw::Utils::Text::get_text_width($self->cache, $self->image_config, 0, $text, '', %font_details);
  my ($width,$height) = @text[2,3];

  return ($width, $height);
}

1;
