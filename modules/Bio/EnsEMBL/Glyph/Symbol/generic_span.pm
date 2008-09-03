=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::generic_span

=head1 DESCRIPTION

Superclass for drawing spans - two-headed arrows, anchored arrows, h-bars, etc
Inheritors should implement start_symbol, end_symbol,top_symbol, bottom_symbol

=head1 ATTRIBS

- bar_style : how to draw the connecting bar.  Default can be different for each
subclass.  One of:
  - line
  - indent
  - full

=cut

package Bio::EnsEMBL::Glyph::Symbol::generic_span;
use strict;
use Sanger::Graphics::Glyph::Poly;

use base qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
  my $self = shift;
  my $parallel = $self->style->{'parallel'};
  if ((!defined $parallel) or (lc($parallel) =~ /y/)){
    $self->draw_parallel();
  } else {
    $self->draw_orthogonal();
  }
}

sub draw_parallel{
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $start = $feature->{'start'};
  my $end = $feature->{'end'};
  my $pix_per_bp = $feature->{'pix_per_bp'};
  my $y_offset = $feature->{'y_offset'};
  my $trunc_start = $feature->{'trunc_start'};
  my $trunc_end = $feature->{'trunc_end'};

  my $linecolour = $style->{'fgcolor'};
  my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};

  my $height = $style->{'height'};

  my $points = []; # polygon points
   
  # want a single poly to represent the arrow (so outline will work nicely)
  # this means we need to push the points on to the arrow array such that
  # if we have to miss out one or both of the arrow heads, then the poly
  # will still join up correctly.
  # Do this by getting the points and widths for the ends (arrowheads) and
  # pushing them on to the array in order:
  # 1) add left arrowhead
  # 2) add top of connecting bar
  # 3) add right arrowhead
  # 4) add bottom of connecting bar
  #
  # The ends should return points drawn in the right order (i.e. clockwise)
 
  my ($start_points, $bar_start) = $self->start_symbol; 
  my ($end_points, $bar_end) = $self->end_symbol; 

  # if the start and end symbols are going to overlap, don't draw them, 
  # and just draw vertical bars instead

  if ($bar_start > $bar_end){
    $bar_start = $start - 1;
    $bar_end = $end;
    $start_points = [$bar_start, $y_offset,
      $bar_start, $y_offset + $height ];
    $end_points = [$bar_end, $y_offset + $height,
      $bar_end, $y_offset ];
  }
  
  # BAR_STYLE can be one of:
  #   full (top = height, bottom = y_offset)
  #   indent (solid bar, indented from height by some chunk)
  #   line (top = bottom)
#    warn Dumper($style);
#    warn "STYLE: ".$style->{'bar_style'}."\n";
  my $bar_style = $style->{'bar_style'} || $self->default_bar_style;
#   warn "BARSTYLE: $bar_style\n";
  my ($bar_top, $bar_bottom);

  if ($bar_style =~ /full/i){
    $bar_bottom = $y_offset;
    $bar_top = $y_offset + $height;
  } elsif ($bar_style =~ /indent/i){
    my $bar_indent = int($height/4);  # artistic choice - nothing magic
    $bar_bottom = $y_offset + $bar_indent;
    $bar_top = $y_offset + $height - $bar_indent;
  } else { # default default to line
    $bar_top = $bar_bottom = $y_offset + $height/2;
    $bar_bottom++;
  }
    
  # 1) add left arrowhead
  push @$points, @$start_points;

  # 2) add top of connecting bar
  push @$points, (
    $bar_start, $bar_top,
    $bar_end, $bar_top
  );

  # 3) add right arrowhead
  push @$points, @$end_points;

  # 4) add bottom of connecting bar
  push @$points, (
    $bar_end, $bar_bottom,
    $bar_start, $bar_bottom
  );

  return new Sanger::Graphics::Glyph::Poly({
    'points'       => $points,
    'colour'       => $fillcolour,
    'bordercolour' => $linecolour,
    'absolutey'    => 1,
    (exists($style->{pattern}) ? (pattern=>$style->{pattern}) : ()),
  });

}


sub draw_orthogonal{
  my $self = shift;
  warn "ORTHOGONAL - haven't implemented this yet...";
  $self->draw_parallel();
}


# Allow each subclass to override the default bar style
sub default_bar_style{
  return 'line';
}


sub start_symbol {
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $start = $feature->{'start'};

  my $points = [];
  my $bar_start = $start - 1;
  return ($points, $bar_start);
}


sub end_symbol {
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $end = $feature->{'end'};

  my $points = [];
  my $bar_end = $end;
  return ($points, $bar_end);
}

1;
