=head1 NAME

Bio::EnsEMBL::Glyph::Symbol::line

=head1 DESCRIPTION

A collection of drawing-code glyphs to represent a line.

=head1 ATTRIBS

STYLE    - 'solid' - normal line (default)
    - 'hat'      - intron style (up/down by strand)
    - 'dashed'- broken line
    - 'chevron'- line with multiple arrow heads

=cut

package Bio::EnsEMBL::Glyph::Symbol::line;
use strict;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Intron;

use base qw(Bio::EnsEMBL::Glyph::Symbol);

sub draw {
  my $self = shift;
  my $style = $self->style;
  my $feature = $self->feature;

  my $y_offset = $feature->{'y_offset'};
  my $pix_per_bp = $feature->{'pix_per_bp'};
  
  my $start = $feature->{'start'};
  my $end = $feature->{'end'};
  my $width = $end - $start + 1;
   
  my $linecolour = $style->{'fgcolor'};
  my $fillcolour = $style->{'bgcolor'} || $style->{'colour'};
  $linecolour ||= $fillcolour;

  my $height = $style->{'height'};

  # Allow style override of orientation
  my $orientation = $style->{'orientation'} || $feature->{'orientation'};
     $orientation = ($orientation == -1 || $orientation eq "-") ? -1 : 1;

  my $linestyle = lc($style->{'style'});
  my $line;
  if ($linestyle eq 'hat' || $linestyle eq 'intron'){
    $line = new Sanger::Graphics::Glyph::Intron({
      'x'        => $start - 1,
      'y'     => $y_offset,
      'width'   => $width,
      'height'  => $height,
      'colour'  => $linecolour,
      'strand'    => $orientation,    
      'absolutey' => 1
    });
  }
  else {
    my $dotted = $linestyle eq 'dashed' ? 1 : 0;
    # tremendously annoying - the gif renderer checks if dotted is defined
    # not if it has a true value, so we have to jump through hoops
    my $params = {
      'x'      => $start -1,
      'y'      => $y_offset + $height/2,
      'width'    => $width,
      'height'   => 0,
      'colour'   => $linecolour,
      'absolutey' => 1,
      ($linestyle eq 'chevron' ? ('chevron'=>$height, 'strand'=>$orientation) : ()),
    };
    $params->{'dotted'} = 1 if $dotted;
    
    $line = new Sanger::Graphics::Glyph::Line($params);
    
  }
  return $line;
}


1;
