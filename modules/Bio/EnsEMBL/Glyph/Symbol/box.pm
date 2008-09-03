=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::box

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a box.

=cut

package Bio::EnsEMBL::Glyph::Symbol::box;
use strict;
use Sanger::Graphics::Glyph::Rect;

use base qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
  my $self       = shift;
  my $style      = $self->style;
  my $feature    = $self->feature;

  my $rowheight  = $feature->{'row_height'};
  my $start      = $feature->{'start'};
  my $end        = $feature->{'end'};
  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset   = $feature->{'y_offset'};
 
  my $linecolour = $style->{'fgcolor'};
  my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};
  $linecolour  ||= $fillcolour;

  my $height     = $style->{'height'};

  return new Sanger::Graphics::Glyph::Rect({
    'x'             => $start-1,
    'y'             => $y_offset,
    'width'         => $end-$start+1,
    'height'        => $height,
    'colour'        => $fillcolour,
    'bordercolour'  => $linecolour,
    'absolutey'     => 1,
    'patterncolour' => $linecolour,
     (exists($style->{pattern}) ? (pattern=>$style->{pattern}) : ()),
  });
}

1;
