package Bio::EnsEMBL::GlyphSet::scalebar;

use strict;

use POSIX qw(floor);

use base qw(Bio::EnsEMBL::GlyphSet);

sub render {
  my ($self, $y) = @_;
  my $container     = $self->{'container'};
  my $length        = $container->length;
  my $contig_strand = $container->can('strand') ? $container->strand : 1;
  my $pix_per_bp    = $self->scalex;
  my $global_start  = $contig_strand < 0 ? -$container->end : $container->start;
  my $global_end    = $contig_strand < 0 ? -$container->start : $container->end;
  my $register_line = $self->get_parameter('opt_lines');
  my $filled        = 1;
  my $last_text_x   = -1e20;
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my ($major_unit, $minor_unit);
  
  if ($length <= 51) {
    $major_unit = 10;
    $minor_unit = 1; 
  } else {
    my $exponent = 10 ** int(log($length) / log(10));
    my $mantissa  = $length / $exponent;
    
    if ($mantissa < 1.2) {
      $major_unit = $exponent / 10;
      $minor_unit = $major_unit / 5;
    } elsif ($mantissa < 2.5) {
      $major_unit = $exponent / 5;
      $minor_unit = $major_unit / 4;
    } elsif ($mantissa < 5) {
      $major_unit = $exponent / 2;
      $minor_unit = $major_unit / 5;
    } else {
      $major_unit = $exponent;
      $minor_unit = $major_unit / 5;
    }
  }
  
  # Black bar all the way along
  $self->push($self->Rect({
    x            => 0, 
    y            => $y,
    width        => $length,
    height       => 3,
    colour       => 'black',
    bordercolour => 'black',
    absolutey    => 1
  }));
  
  my $start = floor($global_start / $minor_unit) * $minor_unit;
  
  while ($start <= $global_end) { 
    my $end       = $start + $minor_unit - 1;
    my $box_start = $start < $global_start ? $global_start : $start;
    my $box_end   = $end   > $global_end   ? $global_end   : $end;
       $filled    = 1 - $filled;
    
    if (!$filled) {
      # white blocks on top of the black bar
      my $t = $self->Rect({
        x            => $box_start - $global_start, 
        y            => $y,
        width        => abs($box_end - $box_start + 1),
        height       => 3,
        colour       => 'white',
        bordercolour => 'black',
        absolutey    => 1
      });

      $self->push($t);
      
      # Vertical lines across all species
      if ($register_line) {
        $end += 0.5 if $end == $start; # stop tags being a cross in small regions
        
        $self->join_tag($t, "ruler_$start", 0, 0, $start            % $major_unit ? 'grey90' : 'grey80');
        $self->join_tag($t, "ruler_$end",   1, 0, ($global_end + 1) % $major_unit ? 'grey90' : 'grey80') unless ($box_end + 1) % $minor_unit;
      }
    }
    
    # Draw the major unit tick 
    unless ($box_start % $major_unit) {
      $self->push($self->Rect({
        x         => $box_start - $global_start,
        y         => $y, 
        width     => 0,
        height    => 5,
        colour    => 'black',
        absolutey => 1
      }));
      
      my $label = $minor_unit < 1000 ? $self->commify($box_start * $contig_strand): $self->bp_to_nearest_unit($box_start * $contig_strand, 2);
      my @res   = $self->get_text_width(($box_start - $last_text_x) * $pix_per_bp * 1.5, $label, '', font => $fontname, ptsize => $fontsize);

      if ($res[0]) {
        $self->push($self->Text({
          x         => $box_start - $global_start,
          y         => defined $y ? $y - $res[3] - 1 : 5,
          height    => $res[3],
          font      => $fontname,
          ptsize    => $fontsize,
          halign    => 'left',
          colour    => 'black',
          text      => $label,
          absolutey => 1
        }));
        
        $last_text_x = $box_start;
      }
    }
  
    $start += $minor_unit;
  }
  
  # Draw the major unit tick 
  unless (($global_end + 1) % $major_unit) {
    $self->push($self->Rect({
      x         => $global_end - $global_start + 1,
      y         => $y,
      width     => 0,
      height    => 5,
      colour    => 'black',
      absolutey => 1
    }));
  }
  
  return undef; # stop text export
}

1;
