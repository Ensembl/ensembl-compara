=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::generic_span

=head1 DESCRIPTION

Superclass for drawing spans - two-headed arrows, anchored arrows, h-bars, etc
Inheritors should implement start_symbol, end_symbol,top_symbol, bottom_symbol

=cut

package Bio::EnsEMBL::Glyph::Symbol::generic_span;
use strict;
use Sanger::Graphics::Glyph::Poly;

use vars qw(@ISA);
use Bio::EnsEMBL::Glyph::Symbol;
@ISA = qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
    my $self = shift;
    my $parallel = $self->style->{'parallel'};
    if ((!defined $parallel) or (lc($parallel) =~ /y/)){
	$self->draw_parallel();
    }
    else {
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
			$bar_start, $y_offset + $height
			];
	$end_points = [$bar_end, $y_offset + $height,
			$bar_end, $y_offset
		      ];
    }

    my $bar_indent = int($height/3) + 1;  # artistic choice - nothing magic
    my $bar_bottom = $y_offset + $bar_indent;
    my $bar_top = $y_offset + $height - $bar_indent;

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
        'points'    => $points,
	'colour'     => $fillcolour,
	'bordercolour' => $linecolour,
        'absolutey' => 1
    });



}

sub draw_orthogonal{
    my $self = shift;
    warn "ORTHOGONAL!";
    return undef;

}

1;
