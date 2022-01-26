=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::scalebar;

### Draws a scalebar as a series of alternating black and white blocks
### marked with base-pair coordinates

### Notes:

## Scalebar divisions should be
##  SMALL ENOUGH
##    to allow a user to be precise
##  BUT BIG ENOUGH
##    to not confuse the eye
##   to allow room for the number underneath.
##
## They should be of a nice size and offset for decimal mental calculations.
##
## We work on arrays of digits, not numbers. That
##  avoids rounding errors etc in floats
##  us to easily track SF, nicely format numbers, etc
##  to write more directly what we intend to do (which is display digits).
##
## We define a minimum size of scalebar major division (ie one with a number)
## in pixels. That should be enough pixels to write a number and leave some
## space, and also big enough not to confuse the eye. We then search through
## all the decimal truncations to find the greatest one which comes in over
## the minimum division size. Finally, we try multiplying by "nice" decimal
## divisors, -- 2, 4, 5 -- to see if we can bump the number up and yet stay
## under the limit.
##
## Number writing uses units if that would truncate more than three digits
## off the number, otherwise it's written literally (takes up no more space
## and no more confusing because there will be lots of digits on rhs of the
## unit based rep at this point).

use strict;

use POSIX qw(floor);

use base qw(EnsEMBL::Draw::GlyphSet);
  
# Least number of pixels per written number. Feel free to tweak.
my $min_pix_per_major = 100;

sub scale {
  my ($from,$to,$max) = @_; 

  my $div = 5;
  my $scale = 1;
  my $skip = 1;

  # Split into array of digits
  my @from_d = split(//,"".$from);
  my @to_d = split(//,"".$to);
  unshift @from_d,"0" for(@from_d..@to_d-1);
  unshift @to_d,"0" for(@to_d..@from_d-1);

  # How many divisions would there be ($d) if we only kept $i digits?
  my $d; 
  my $unit = -1; 
  foreach my $i (0..@from_d-1) {
    my $a_v = join("",@from_d[0..@from_d-$i-1])+0;
    my $b_v = join("",@to_d[0..@from_d-$i-1])+0;
    $d = $b_v-$a_v;
    if($d) {
      if($d <= $max) {
        $unit = ("1".("0" x $i))+0;
        last;
      }   
    }   
  }
  return [("1".("0" x @from_d)),1,1] if $unit == -1;
  # Improve things by trying simple multiples of 1<n zeroes>.
  # (eg if 100 will fit will 200, 400, 500).
  if($d*5 <= $max) { $unit /=5; $div = 2; }
  elsif($d*4 <= $max) { $unit /=4; $skip = 2; $div = 1; }
  elsif($d*2 <= $max) { $unit /=2; $skip = 2; }
  $skip = 1 unless $d > 2;
  $unit = 1 if $unit < 1;
  return [$unit,$div,$unit*$skip];
}

sub format_a_number {
  my ($self,$num,$step) = @_;

  # Format numbers like it's 1990, to avoid weird floaty rounding issues.
  $step =~ /(0+)$/;
  my $strip = length $1;
  my @lhs = split(//,"".$num);
  if($strip>=3) {
    # format "w.xyz [kM]b"
    my $mul = int((@lhs-1)/3);
    my @rhs = splice(@lhs,@lhs-$mul*3);
    pop @rhs for(1..$strip);
    unshift @rhs,"." if @rhs;
    return join("",@lhs,@rhs,['','k','M','G']->[$mul],"b");
  } else {
    # format: "a,bcd,efg"
    return $self->commify($num);
  }
}

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
  

  my $max_major_divs = $length*$pix_per_bp/$min_pix_per_major;
  
  my ($major,$div,$labmaj) = @{scale($container->start,$container->end,$max_major_divs)};

  $major_unit = $major;
  $minor_unit = $major_unit / $div;
  $minor_unit = $major_unit if $minor_unit < 1;

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
        
        $self->join_tag($t, "ruler_$start", 0, 0, $start            % $major_unit ? 'grey90' : 'grey80', undef, -100);
        $self->join_tag($t, "ruler_$end",   1, 0, ($global_end + 1) % $major_unit ? 'grey90' : 'grey80', undef, -100) unless ($box_end + 1) % $minor_unit;
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
      $label = $self->format_a_number($box_start*$contig_strand,$labmaj);
      my @res   = $self->get_text_width(($box_start - $last_text_x) * $pix_per_bp * 1.5, $label, '', font => $fontname, ptsize => $fontsize);

      if ($res[0] && !(($box_start*$contig_strand) % $labmaj)) {
        $self->push($self->Text({
          x         => ($box_start - $global_start + 0.5) - ($res[2]/2) / $self->scalex,
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

