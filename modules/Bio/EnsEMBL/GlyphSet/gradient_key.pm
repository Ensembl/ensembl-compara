=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Sanger::Graphics::GlyphSet::gradient_key;

use strict;

use base qw(EnsEMBL::Web::GlyphSet);

sub _init {
  my ($self) = @_;

  my $container  = $self->{'container'};
  my $length     = $container->length();
  my $Config     = $self->{'config'};
  my $im_width   = $Config->image_width();

  return if ($length > $Config->get('MVP_gradient', 'cutoff'));

  my $start      = $container->start();
  my $end        = $container->end()+1;
  my $pix_per_bp = $Config->transform->{'scalex'};
  my $fontname        = "Tiny";
  my $fontwidth_bp    = $Config->texthelper->width($fontname),
  my ($fontwidth, $fontheight)       = $Config->texthelper->px2bp($fontname),

  my $coloursteps     = 100;
  my $colours         = $Config->get('MVP_gradient', 'colours') || [qw( yellow2 green3 blue)];
  my @range = $self->{'config'}->colourmap->build_linear_gradient($coloursteps, @{$colours});
    
  my $glyph_width_bp  = $length/$coloursteps;
  
  my $h = 7;
    
  for( my $i = 0; $i < $coloursteps; $i++ ) {
    my $colour          = $range[int($i)];
    $self->push($self->Rect({
      'x'            => ($i * $glyph_width_bp),
      'y'            => 0,
      'width'        => $glyph_width_bp,
      'height'       => $h,
      'colour'       => $colour,
      'border'       => 1,
      'bordercolour' => 'black',
      'absolutey'    => 1,
      'title'        => sprintf("Score: %d", $i + 1)
    });
  }

  $h = 9;
  foreach my $i (0,20,40,60,80) {
    my $text    = "$i%";
    my $x       = $length * ($i/100);
    $self->push($self->Text({
      'x'             => $x,
      'y'             => $h,
      'height'        => $fontheight,
      'font'          => $fontname,
      'colour'        => 'black',
      'text'          => $text,
      'absolutey'     => 1,
    }));
  }
    
  my $text    = "100%";
  $self->push($self->Text({
    'x'             => 97 * $glyph_width_bp,
    'y'             => $h,
    'height'        => $fontheight,
    'font'          => $fontname,
    'colour'        => 'black',
    'text'          => $text,
    'absolutey'     => 1,
  }));
}
1;
