=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::span

=head1 DESCRIPTION

Subclass of generic_span to implement H-bar type span symbol

=cut

package Bio::EnsEMBL::Glyph::Symbol::span;
use strict;
use Sanger::Graphics::Glyph::Poly;

use base qw(Bio::EnsEMBL::Glyph::Symbol::generic_span);


# Has to return the points to draw (as an arrayref), and the x-coord at which
# the connecting bar should start (i.e. the rightmost point of the arrowhead).
# Points should be drawn clockwise from the bottom.

sub start_symbol {  # Vertical bar
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $start = $feature->{'start'};
  my $y_offset = $feature->{'y_offset'};
  my $trunc_start = $feature->{'trunc_start'};

  my $height = $style->{'height'};

  my $points = [];
  my $bar_start = $start - 1;

  unless ($trunc_start){
    push @$points, (
      $bar_start, $y_offset,
      $bar_start, $y_offset + $height
    );
  }
  
  return ($points, $bar_start);
}


# Has to return the points to draw (as an arrayref), and the x-coord at which
# the connecting bar should end (i.e. the leftmost point of the arrowhead).
# Points should be drawn clockwise from the top.
sub end_symbol {  # Also a vertical bar 
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};

  my $end = $feature->{'end'};
  my $trunc_end = $feature->{'trunc_end'};

  my $height = $style->{'height'};

  my $points = [];
  my $bar_end = $end;

  unless ($trunc_end){
    push @$points, (
      $bar_end, $y_offset + $height,
      $bar_end, $y_offset
    );
  }
  
  return ($points, $bar_end);
}


sub default_bar_style {
  return 'line';
}

1;
