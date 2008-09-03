=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::ex

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent an X.  Centred on range of feature.

=head1 ATTRIBS

- point : if true, draws the symbol the default width, otherwise it is scaled
to the feature width

- linewidth : if a point feature, specifies the width of the symbol

=cut

package Bio::EnsEMBL::Glyph::Symbol::ex;
use strict;
use Sanger::Graphics::Glyph::Line;

use base qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $y_offset = $feature->{'y_offset'};
  my $pix_per_bp = $feature->{'pix_per_bp'};
  
  my $start = $feature->{'start'};
  my $end = $feature->{'end'};
   
  my $linecolour = $style->{'fgcolor'};
  my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};
  $linecolour ||= $fillcolour;

  my $mid_x = $start + (($end - $start)/2) - 1;
  my ($width, $start_x);

  my $height = $style->{'height'};

  # is this a point feature, or do we want to scale across the feature?
  if (($end - $start <= 1) || $style->{'point'}){  # point feature
    $width =  $style->{'linewidth'} || $height;
    $width /= $pix_per_bp;  # remember, x in bp, y in pixels
    $start_x = $mid_x -$width/2;
  }
  else {  # Scale to full feature width
    $width = $end - $start;
    $start_x = $start - 1;
  }


  return (
    new Sanger::Graphics::Glyph::Line({
      'x'      => $start_x,
      'y'      => $y_offset,
      'width'    => $width,
      'height'   => $height,
      'colour'   => $linecolour,
      'absolutey' => 1
    }),
    new Sanger::Graphics::Glyph::Line({
      'x'      => $start_x,
      'y'      => $y_offset + $height,
      'width'    => $width,
      'height'   => -$height,
      'colour'   => $linecolour,
      'absolutey' => 1
    })
  );
}


1;
