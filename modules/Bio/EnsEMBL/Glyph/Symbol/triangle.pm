=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::triangle

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a triangle.

=head1 ATTRIBS

- point : if true, draws the triangle on the centre point, otherwise it is
drawn across the feature width

- linewidth : if a point feature, specifies the width of the symbol

- direction: one of N, E, S, W - way in which the triangle points

- orient: one of N, E, S, W - side on which the base should be

Note that orient and direction have completely opposite senses.  Orient is
there for compatability with Bio::Graphics interpretation of the DAS spec.
Direction is for the other interpretation of the spec.

=cut

package Bio::EnsEMBL::Glyph::Symbol::triangle;
use strict;
use Sanger::Graphics::Glyph::Poly;

use base qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $start = $feature->{'start'};
  my $end = $feature->{'end'};
  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};

  my $linecolour = $style->{'fgcolor'};
  my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};
  $linecolour ||= $fillcolour;

  my $height = $style->{'height'};
  my ($start_x, $width);

  # is this a point feature, or do we want to scale across the feature?
  if (($end - $start <= 1) || $style->{'point'}){  # point feature
    $width =  $style->{'linewidth'} || $height;
    $width /= $pix_per_bp;  # remember, x in bp, y in pixels
    my $mid_x = $start + (($end - $start)/2) - 1;
    $start_x = $mid_x -$width/2;
  }
  else {  # Scale to full feature width
    $width = $end - $start;
    $start_x = $start - 1;
  }

  my $points = [];

  # get direction or orient[ation]
  # If we've got an orient, need to invert it to get direction.  FFS.
  my $direction = uc($style->{'direction'});
  unless ($direction){
    $direction = uc($style->{'orient'});
    $direction =~ tr/NESW/SWNE/;
  }
  
  if ($direction eq 'E'){ # |>
    push @$points, (
      $start_x, $y_offset,
      $start_x, $y_offset + $height,
      $start_x + $width, $y_offset + $height/2
    );
  } elsif($direction eq 'W'){ # <|
    push @$points, (
      $start_x + $width, $y_offset,
      $start_x, $y_offset + $height/2,
      $start_x + $width, $y_offset + $height,
    );
  } elsif($direction eq 'S'){ # V 
    push @$points, (
      $start_x, $y_offset,
      $start_x + $width/2, $y_offset + $height,
      $start_x + $width, $y_offset
    );
  } else {  # upwards-pointing arrows are the new black
    push @$points, (
      $start_x, $y_offset + $height,
      $start_x + $width, $y_offset + $height,
      $start_x + $width/2, $y_offset,
    );
  }

  return new Sanger::Graphics::Glyph::Poly({
    'points'       => $points,
    'colour'       => $fillcolour,
    'bordercolour' => $linecolour,
    'absolutey'    => 1
  });

}

1;
