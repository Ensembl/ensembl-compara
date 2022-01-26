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

package EnsEMBL::Draw::GlyphSet::Vdraggable;

### "Invisible" glyph used to define drag'n'select capability of vertical ideogram

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub render_normal {
  my ($self) = @_;

  my $chr = $self->{'container'}{'chr'};
  my $slice_adaptor = $self->{'container'}->{'sa'};
  my $slice = $slice_adaptor->fetch_by_region(undef, $chr);
  my $len   = $slice->length;
  my $c_w   = $self->get_parameter('container_width');
  my $glyph = $self->Space({
    'x'         => $c_w - $len,
    'y'         => 0,
    'width'     => $len,
    'height'    => 1,
    'absolutey' => 1,
  });

  $self->push($glyph);
  my $A = $self->my_config('part');

  my $href = join '|',
    '#vdrag', $self->get_parameter('slice_number') || 1,
    $self->{'container'}->{'web_species'}, $chr,
    1, $len, 1;

  my @common = ( 
    'y'     => $A,
    'style' => 'fill', 
    'z'     => -10,
    'href'  => $href, 
    'class' => 'vdrag'
  );
  
  $self->join_tag($glyph, 'draggable', { 'x' => $A, @common });
  $self->join_tag($glyph, 'draggable', { 'x' => 1 - $A, @common });
}

1;
