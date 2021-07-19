=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::lrg_scalebar;

### Scalebar on LRG/Summary - shows coordinates relative to LRG slice,
### rather than normal chromosomal coordinates

use strict;

use POSIX qw(floor);

use base qw(EnsEMBL::Draw::GlyphSet);

sub render {
  my ($self, $y) = @_;
  
  my $container      = $self->{'container'};
  my $length         = $container->length;
  
  my $contig_strand  = $container->can('strand') ? $container->strand : 1;
  my $pix_per_bp     = $self->scalex;
  
  my $global_start   = $contig_strand < 0 ? -$container->end : $container->start;
  my $global_end     = $contig_strand < 0 ? -$container->start : $container->end;
  
  my $register_line  = $self->get_parameter('opt_lines');
  my $feature_colour = $self->get_parameter('col');
  
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
  
  my $start = floor($global_start / $minor_unit) * $minor_unit;
  my $filled = 1;
  my $last_text_x = -1e20;
  
  while ($start <= $global_end) { 
    my $end       = $start + $minor_unit - 1;
    my $box_start = $start < $global_start ? $global_start : $start;
    my $box_end   = $end   > $global_end   ? $global_end   : $end;
    
    $filled = 1 - $filled;
    
    # Draw the glyph for this box
    my $t = $self->Rect({
      'x'         => $box_start - $global_start, 
      'y'         => $y,
      'width'     => abs($box_end - $box_start + 1),
      'height'    => 3,
      ( $filled == 1 ? 'colour' : 'bordercolour' ) => 'black',
      'absolutey' => 1
    });

    $self->push($t);
    
    # Vertical lines across all species
    if ($register_line) {
      # This is the end of the box
      if ($start == $box_start) {
        $self->join_tag($t, "ruler_$start", 0, 0 , $start % $major_unit ? 'grey90' : 'grey80');
      } elsif (($box_end == $global_end) && !(($box_end + 1) % $minor_unit)) {
        $self->join_tag($t, "ruler_$end", 1, 0 ,($global_end + 1) % $major_unit ? 'grey90' : 'grey80');
      }
    }
    
    # Draw the major unit tick 
    unless ($box_start % $major_unit) {
      $self->push($self->Rect({
        'x'         => $box_start - $global_start,
        'y'         => $y, 
        'width'     => 0,
        'height'    => 5,
        'colour'    => 'black',
        'absolutey' => 1
      }));
      
      my $label = $minor_unit < 1000 ? $self->commify($box_start * $contig_strand): $self->bp_to_nearest_unit($box_start * $contig_strand, 2);
      
      my @res = $self->get_text_width(($box_start - $last_text_x) * $pix_per_bp * 1.5, $label, '', 'font' => $fontname, 'ptsize' => $fontsize);

      if ($res[0]) {
        $self->push($self->Text({
          'x'         => $box_start - $global_start,
          'y'         => defined $y ? $y - $res[3] - 1 : 5,
          'height'    => $res[3],
          'font'      => $fontname,
          'ptsize'    => $fontsize,
          'halign'    => 'left',
          'colour'    => $feature_colour,
          'text'      => $label,
          'absolutey' => 1
        }));
        
        $last_text_x = $box_start;
      }
    }
  
    $start += $minor_unit;
  }
  
  # Draw the major unit tick 
  unless (($global_end + 1) % $major_unit) {
    $self->push($self->Rect({
      'x'         => $global_end - $global_start + 1,
      'y'         => $y,
      'width'     => 0,
      'height'    => 5,
      'colour'    => 'black',
      'absolutey' => 1
    }));
  }
}

1;
