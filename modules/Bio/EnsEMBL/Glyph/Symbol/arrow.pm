=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::arrow

=head1 DESCRIPTION

Subclass of generic_span to implement double-headed arrow

=cut

package Bio::EnsEMBL::Glyph::Symbol::arrow;
use strict;

use base qw(Bio::EnsEMBL::Glyph::Symbol::generic_span);


# Has to return the points to draw (as an arrayref), and the x-coord at which
# the connecting bar should start (i.e. the rightmost point of the arrowhead).
# Points should be drawn clockwise.

sub start_symbol {  # Left-pointing arrowhead
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $start = $feature->{'start'};
  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};
  my $trunc_start = $feature->{'trunc_start'};

  my $height = $style->{'height'};

  my $headwidth = $height/2/$pix_per_bp;  # width of arrow head in basepairs
                      # (x is in basepairs, y in pixels)

  my $points = [];
  my $bar_start = $start - 1;

  unless ($trunc_start){
    $bar_start = $bar_start + $headwidth;
    push @$points, (
      $bar_start, $y_offset,
      $start - 1, $y_offset + $height/2,
      $bar_start, $y_offset + $height
    );
  }
  
  return ($points, $bar_start);
}


sub end_symbol {  # Right-pointing arrowhead
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};

  my $end = $feature->{'end'};
  my $trunc_end = $feature->{'trunc_end'};

  my $height = $style->{'height'};

  my $headwidth = $height/2/$pix_per_bp;  # width of arrow head in basepairs
                      # (x is in basepairs, y in pixels)

  my $points = [];
  my $bar_end = $end;

  unless ($trunc_end){
    $bar_end = $bar_end - $headwidth;
    push @$points, (
      $bar_end, $y_offset + $height,
      $end, $y_offset + $height/2,
      $bar_end, $y_offset
    );
  }
  
  return ($points, $bar_end);
}

sub default_bar_style {
  return 'line';
}


1;
