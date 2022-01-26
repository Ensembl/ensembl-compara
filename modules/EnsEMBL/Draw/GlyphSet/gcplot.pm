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

package EnsEMBL::Draw::GlyphSet::gcplot;

### Draws the %GC plot on Region in Detail

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self  = shift;
  my $slice = $self->{'container'};
  
  return unless @{$slice->project('seqlevel')}; # check we are not in a big gap
  
  my $vclen    = $slice->length;
  my $im_width = $self->{'config'}->image_width;
  my $divs     = int($im_width / 2);
  my $divlen   = $vclen / $divs;
  
  return $self->_init_block if $vclen < 200; # Display blocks for very short sequences
  
  my $h           = 20;
  my $colour      = $self->my_config('col')  || 'gray50';
  my $line_colour = $self->my_config('line') || 'red';
  my $seq         = uc $slice->seq;
  my @gc;
  
  $divlen = 10 if $divlen < 10; # Increase the number of points for short sequences
  
  foreach my $i (0..$divs-1) {
    my $subseq = substr $seq, int($i * $divlen), int $divlen;
    my $GC     = $subseq =~ tr/GC/GC/;
    my $value  = 9999;
    
    if (length $subseq > 0) { # catch divide by zero
      $value = $GC / length $subseq;
      $value = $value < .25 ? 0 : ($value >.75 ? .5 : $value -.25);
    }
    
    push @gc, $value;
  }
  
  my $value = shift @gc;
  my $x     = 0;

  foreach my $new (@gc) {
    unless ($value == 9999 || $new == 9999) {
      $self->push($self->Line({
        x         => $x,
        y         => $h * (1 - 2 * $value),
        width     => $divlen,
        height    => ($value - $new) * 2 * $h,
        colour    => $colour,
        absolutey => 1,
      })); 
    }
    
    $value = $new;
    $x    += $divlen;
  }
  
  $self->push($self->Line({
    x         => 0,
    y         => $h / 2, # 50% point for line
    width     => $vclen,
    height    => 0,
    colour    => $line_colour,
    absolutey => 1,
  }));
}  

sub _init_block {
  my $self   = shift;
  my $seq    = uc $self->{'container'}->seq;
  my $colour = $self->my_config('col') || 'gray50';
  my $y      = $self->errorTrack('Blocks show the locations of G/C base pairs.');
  my $h      = 10;
  my $x      = 0;
  
  foreach (split //, $seq) {
    if (/[GC]/) {
      $self->push($self->Rect({
        x         => $x,
        y         => $y + $h / 2,
        width     => 1,
        height    => $h,
        colour    => $colour,
        absolutey => 1
      }));
    }
    
    $x++;
  }
}

1;
