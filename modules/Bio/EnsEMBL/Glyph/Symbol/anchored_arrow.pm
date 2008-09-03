=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::anchored_arrow

=head1 DESCRIPTION

Subclass of generic_span to implement a directional arrow with an arrowhead
at one end and a vertical bar at the other:  |----->

=head1 ATTRIBS

- orientation: +/- force direction of arrow
- no_anchor:  turn off anchor

=cut

package Bio::EnsEMBL::Glyph::Symbol::anchored_arrow;
use strict;
use base qw(Bio::EnsEMBL::Glyph::Symbol::generic_span);


# Has to return the points to draw (as an arrayref), and the x-coord at which
# the connecting bar should start (i.e. the rightmost point of the
# anchored_arrowhead).  Points should be drawn clockwise.

sub start_symbol {  
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $start = $feature->{'start'};
  my $orientation = $self->orientation;
  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};
  my $trunc_start = $feature->{'trunc_start'};

  my $height = $style->{'height'};

  my $points = [];
  my $bar_start = $start - 1;

  unless ($trunc_start){
    if ($orientation == -1){  # backwards arrow:  <-
      my $headwidth = $height/2/$pix_per_bp;
      $bar_start = $bar_start + $headwidth;
      push @$points, (
        $bar_start, $y_offset,
        $start - 1, $y_offset + $height/2,
        $bar_start, $y_offset + $height
      );
    }
    else {    # anchor at this end: |-
      unless ($style->{'no_anchor'}){
        push @$points, (
          $bar_start, $y_offset,
          $bar_start, $y_offset + $height
        );
      }
    }
  }
  
  return ($points, $bar_start);
}


sub end_symbol {  
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};

  my $end = $feature->{'end'};
  my $orientation = $self->orientation;
  my $trunc_end = $feature->{'trunc_end'};

  my $height = $style->{'height'};

  my $headwidth = $height/2/$pix_per_bp;  # width of arrow head in basepairs
                      # (x is in basepairs, y in pixels)

  my $points = [];
  my $bar_end = $end;
  unless ($trunc_end){
    if ($orientation == 1){  # forwards arrow:  ->
      my $headwidth = $height/2/$pix_per_bp;
      $bar_end = $bar_end - $headwidth;
      push @$points, (
        $bar_end, $y_offset + $height,
        $end, $y_offset + $height/2,
        $bar_end, $y_offset
      );
    }
    else {    # anchor at this end: -|
      unless ($style->{'no_anchor'}){
        push @$points, (
          $bar_end, $y_offset + $height,
          $bar_end, $y_offset
        );
      }
    }
  }
  
  return ($points, $bar_end);
}

sub default_bar_style {
  return 'indent';
}


# orientation pulled out into a sub so can override in subclass
# and force direction for farrow and rarrow (legacy symbols)
# Returns -1 for -ve direction, +1 otherwise

sub orientation {

  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  # Allow style override of orientation
  my $orientation = $style->{'orientation'} || $feature->{'orientation'};
  if ($orientation == -1 or $orientation eq "-"){
    $orientation = -1;
  }
  else {
    $orientation = 1;
  }
  return $orientation;
}

1;
