=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::rarrow

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a reverse-pointing arrow.

=cut

package Bio::EnsEMBL::Glyph::Symbol::rarrow;
use strict;
use Sanger::Graphics::Glyph::Poly;

use vars qw(@ISA);
use Bio::EnsEMBL::Glyph::Symbol;
@ISA = qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
    my $self = shift;
    my $style = $self->style;
    my $feature = $self->feature;

    my $rowheight = $feature->{'row_height'};
    my $start = $feature->{'start'};
    my $end = $feature->{'end'};
    my $pix_per_bp = $feature->{'pix_per_bp'};
    my $y_offset = $feature->{'y_offset'};
    
    my $linecolour = $style->{'fgcolor'};
    my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};

    my $height = $style->{'height'};

    my $slope = $height/2/$pix_per_bp;

    my $points = ( $end - $start + 1 > $slope ) ?
    [
      $end,                $y_offset,
      $end,                $y_offset + $height,
      $start - 1 + $slope, $y_offset + $height,
      $start - 1,          $y_offset + $height/2,
      $start - 1 + $slope, $y_offset
    ] : [
      $end,                $y_offset,
      $end,                $y_offset + $height,
      $start-1,            $y_offset + $height/2
    ];
    return new Sanger::Graphics::Glyph::Poly({
        'points'    => $points,
	'colour'     => $fillcolour,
	'bordercolour' => $linecolour,
        'absolutey' => 1
    });

}

1;
