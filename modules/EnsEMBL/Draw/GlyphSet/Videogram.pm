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

package EnsEMBL::Draw::GlyphSet::Videogram;

### Module for drawing vertical ideograms on location views - whole
### karyotypes, single chromosomes and synteny

use strict;

use Carp;
use warnings;
no warnings 'uninitialized';

use List::Util qw(sum);
use EnsEMBL::Draw::Utils::ColourMap;

use base qw(EnsEMBL::Draw::GlyphSet::Videogram_legend);

sub _init {
  my ($self) = @_;
  my $config = $self->{'config'};
  my $i_w    = $self->get_parameter('image_height');
  my $c_w    = $self->get_parameter('container_width');
  
  return unless $c_w;

  $self->_init_bump($_) for qw(_bump_forward _bump_reverse);
  
  my $chr           = $self->{'container'}{'chr'} || $self->{'extras'}{'chr'};
  my $slice_adaptor = $self->{'container'}{'sa'};
  my $slice         = $slice_adaptor->fetch_by_region(undef, $chr) or (carp "$slice_adaptor has no fetch_by_region(undef, $chr)" && return);
  
  $self->{'pix_per_bp'} = $i_w / $c_w;
  
  my $black         = 'black';
  my $bg            = 'background2';
  my $top_margin    = $self->get_parameter('top_margin');
  my ($w, $h)       = $self->{'config'}->texthelper->Vpx2bp('Tiny');
  my @bands         = sort { $a->start <=> $b->start } @{$self->{'container'}{'ka'}->fetch_all_by_chr_name($chr)};
  my $chr_length    = $slice->length || 1;
  my $bpperpx       = $c_w / $config->get_parameter('image_height');
  my $v_offset      = $c_w - $chr_length; # bottom align each chromosome
  my $done_1_acen   = 0;                  # flag for tracking place in chromosome
  my $wid           = $self->my_config('width')   || 24;
  my $padding       = $self->my_config('padding') || 6;
  my $style         = $self->my_config('style')   || '';
  my $h_wid         = int $wid / 2;
  my $h_offset      = $style eq 'text' ? $padding : int(($self->my_config('totalwidth') || 0) - $wid - ($self->get_parameter('band_labels') eq 'on' ? ($w * 6 + 4) : 0)) / 2; # get text labels in correct place
  my @decorations;

  if ($padding) {
    # make sure that there is a blank image behind the chromosome so that the glyphset doesn't get "horizontally" squashed.
    $self->push($self->Space({
      x         => $c_w - $chr_length / 2,
      y         => $h_offset - $padding * 1.5,
      width     => 1,
      height    => $padding * 3 + $wid,
      absolutey => 1,
    }));
  }
  
  my $alt_stain = 25;
  
  if (scalar @bands) {
    foreach my $band (@bands) {
      my $stain = lc $band->stain;
      
      my $bandname      = $band->name;
      my $vc_band_start = $band->start + $v_offset;
      my $vc_band_end   = $band->end   + $v_offset;
      my %extra;
      
      if ($self->get_parameter('band_links') eq 'yes') {
        %extra = (
          title => 'Band: ' . ($stain eq 'acen' ? 'Centromere' : $bandname),
          href  =>  $self->_url({
            type    => 'Location',
            action  => 'View',
            r       => "$chr:$vc_band_start-$vc_band_end",
            __clear => 1,
          }),
        );
      }
      
      if (!$stain) {
        $stain     = "gpos$alt_stain";
        $alt_stain = 100 - $alt_stain;
      }
      
      my $colour = $self->my_colour($stain);
      
      if ($stain eq 'acen') {
        if ($done_1_acen or $band->start == 1) {
          CORE::push(@decorations, $self->Poly({
            points    => [ $vc_band_start, $h_offset + $h_wid, $vc_band_end, $h_offset, $vc_band_end, $h_offset + $wid ],
            colour    => $colour,
            absolutey => 1,
            %extra
          }));
        } else {
          CORE::push(@decorations, $self->Poly({
            points    => [ $vc_band_start, $h_offset, $vc_band_end, $h_offset + $h_wid, $vc_band_start, $h_offset + $wid ],
            colour    => $colour,
            absolutey => 1,
            %extra
          }));
          
          $done_1_acen = 1;
        }
      } elsif ($stain eq 'stalk') {
         CORE::push(@decorations,
           $self->Poly({
            points    => [ $vc_band_start, $h_offset, $vc_band_end, $h_offset + $wid, $vc_band_end, $h_offset, $vc_band_start, $h_offset + $wid ],
            colour    => $colour,
            absolutey => 1,
            %extra
          }),
          $self->Rect({
            x         => $vc_band_start,
            y         => $h_offset    + int $wid / 4,
            width     => $vc_band_end - $vc_band_start,
            height    => $h_wid,
            colour    => $colour,
            absolutey => 1,
            %extra
          })
        );
      } else {
        if ($self->get_parameter('hide_bands') eq 'yes') {
          $stain  = 'gneg';
          $colour = $self->my_colour('gneg');
        }
        
        my $R = $vc_band_start;
        my $T = $bpperpx * ((int $vc_band_end / $bpperpx) - (int $vc_band_start / $bpperpx));
        
        $self->push(
          $self->Rect({
            x         => $R,
            y         => $h_offset,
            width     => $T,
            height    => $wid,
            colour    => $colour,
            absolutey => 1,
            %extra
          }),
          $self->Line({
            x         => $R,
            y         => $h_offset,
            width     => $T,
            height    => 0,
            colour    => $black,
            absolutey => 1,
          }),
          $self->Line({
            x         => $R,
            y         => $h_offset + $wid,
            width     => $T,
            height    => 0,
            colour    => $black,
            absolutey => 1,
          })
        );
      }
      
      # only add the band label if the box is big enough to hold it
      if (
        $self->get_parameter('band_labels') eq 'on' && # Only if turned on
        $stain !~ /^(acen|tip|stalk)$/              && # Not on "special" bands
        $h < $vc_band_end - $vc_band_start             # Only if the box is big enough!
      ) {
        $self->push($self->Text({
          x         => ($vc_band_end + $vc_band_start - $h) / 2,
          y         => $h_offset + $wid + 4,
          width     => $h,
          height    => $w * length $bandname,
          font      => 'Tiny',
          colour    => $black,
          text      => $bandname,
          absolutey => 1,
        }));
      }
    }
  } else {
    foreach (0, $wid) {
      $self->push($self->Line({
        x         => $v_offset - 1,
        y         => $h_offset + $_,
        width     => $chr_length,
        height    => 0,
        colour    => $black,
        absolutey => 1,
      }));
    }
  }
  
  $self->push(@decorations);
  
  my $species_defs = $self->species_defs;
  my %partials     = map { uc($_) => 1 } @{$species_defs->PARTIAL_CHROMOSOMES    || []};
  my %artificials  = map { uc($_) => 1 } @{$species_defs->ARTIFICIAL_CHROMOSOMES || []};
  
  # Draw the ends of the ideogram
  foreach my $end (
    ( @bands && $bands[ 0]->stain eq 'tip' ? () : 0 ),
    ( @bands && $bands[-1]->stain eq 'tip' ? () : 1 )
  ) {
    my $direction = $end ? -1 : 1;
    
    if ($partials{uc $chr}) {
      # draw jagged ends for partial chromosomes resolution dependent scaling
      my $mod = ($wid < 16) ? 0.5 : 1;
      
      for my $i (1..8*$mod) {
        my $x      = $v_offset + $chr_length * $end - 4 * (($i % 2) - 1) * $direction * $bpperpx * $mod;
        my $y      = $h_offset + $wid / (8 * $mod) * ($i - 1);
        my $width  = 4 * (-1 + 2 * ($i % 2)) * $direction * $bpperpx * $mod;
        my $height = $wid / (8 * $mod);
    
        # overwrite karyotype bands with appropriate triangles to produce jags
        $self->push($self->Poly({
          points         => [ $x, $y, $x + $width * (1 - ($i % 2)),$y + $height * ($i % 2), $x + $width, $y + $height, ],
          colour         => $bg,
          absolutey      => 1,
          absoluteheight => 1,
        }));
    
        # the actual jagged line
        $self->push($self->Line({
          x              => $x,
          y              => $y,
          width          => $width,
          height         => $height,
          colour         => $black,
          absolutey      => 1,
          absoluteheight => 1,
        }));
      }
    
      # black delimiting lines at each side
      foreach (0, $wid) {
        $self->push($self->Line({
          x             => $v_offset,
          y             => $h_offset + $_,
          width         => 4,
          height        => 0,
          colour        => $black,
          absolutey     => 1,
          absolutewidth => 1,
        }));
      }
    } elsif (
      $artificials{uc $chr}                                ||
      ($end == 0 && @bands && $bands[0]->stain  eq 'ACEN') ||
      ($end == 1 && @bands && $bands[-1]->stain eq 'ACEN') ||
      ($end == 0 && $chr =~ /Q|q/mx)                       ||
      ($end == 1 && $chr =~ /P|p/mx)
    ) {
      # draw blunt ends for artificial chromosomes or chr arms
      my $x      = $v_offset + $chr_length * $end - 1;
      my $y      = $h_offset;
      my $width  = 0;
      my $height = $wid;

      $self->push($self->Line({
        x             => $x,
        y             => $y,
        width         => $width,
        height        => $height,
        colour        => $black,
        absolutey     => 1,
        absolutewidth => 1,
       }));
    } else {
      # round ends for full chromosomes
      my $max_rows = $chr_length / $bpperpx / 2;
      my @lines    = $wid < 16 ? ([8, 6], [4, 4], [2, 2]) : ([8, 5], [5, 3], [4, 1], [3, 1], [2, 1], [1, 1], [1, 1], [1, 1]);
      
      for my $I (0..$#lines) {
        next if $I > $max_rows;
        
        my ($bg_x, $black_x) = @{$lines[$I]};
        my $xx               = $v_offset + $chr_length * $end + ($I + 0.5 * $end) * $direction * $bpperpx + ($end ? $bpperpx : 10);
        
        $self->push(
          $self->Line({
            x         => $xx,
            y         => $h_offset,
            width     => 0,
            height    => $wid * $bg_x / 24 -1,
            colour    => 'background1',
            absolutey => 1,
          }),
          $self->Line({
            x         => $xx,
            y         => $h_offset + 1 + $wid * (1 - $bg_x / 24),
            width     => 0,
            height    => $wid * $bg_x / 24 - 1,
            colour    => 'background1',
            absolutey => 1,
          }),
          $self->Line({
            x         => $xx,
            y         => $h_offset + $wid * $bg_x / 24,
            width     => 0,
            height    => $wid * $black_x / 24 - 1,
            colour    => $black,
            absolutey => 1,
          }),
          $self->Line({
            x         => $xx,
            y         => $h_offset + 1 + $wid * (1 - $bg_x / 24 - $black_x / 24),
            width     => 0,
            height    => $wid * $black_x / 24 - 1,
            colour    => $black,
            absolutey => 1,
          })
        );
      }
    }
  }
  
  # Add highlights
  if (defined $self->{'highlights'} && $self->{'highlights'} ne '') {
    my $colourmap = new EnsEMBL::Draw::Utils::ColourMap;

    foreach my $highlight_set (reverse @{$self->{'highlights'}}) {
      my $highlight_style  = $style || $highlight_set->{'style'};
      my $type             = "highlight_$highlight_style";
      my $aggregate_colour = $config->{'_aggregate_colour'};
      
      if ($highlight_set->{$chr}) {
        # Firstly create a highlights array which contains merged entries!
        my @temp_highlights = @{$highlight_set->{$chr}};
        my @highlights;
        
        if ($highlight_set->{'merge'} eq 'no') {
          @highlights = @temp_highlights;
        } else {
          my $bin_length    = $padding * ($highlight_style eq 'arrow' ? 1.5 : 1) * $bpperpx;
          my $is_aggregated = 0;
          my @bin_flag;
          
          foreach (@temp_highlights) {
            my $bin_id = int (2 * $v_offset + $_->{'start'} + $_->{'end'}) / 2 / $bin_length;
               $bin_id = 0 if $bin_id < 0;
            
            # We already have a highlight in this bin - so add this one to it
            if (my $offset = $bin_flag[$bin_id]) {
              # Build zmenu
              my $zmenu_length = keys %{$highlights[$offset-1]->{'zmenu'}};
              
              foreach my $entry (sort keys %{$_->{'zmenu'}}) {
                next if $entry eq 'caption';
                
                my $value = $_->{'zmenu'}{$entry};
                   $entry =~ s/\d\d+://mx;
                
                $highlights[$offset - 1]{'zmenu'}{sprintf '%03d:%s', $zmenu_length++, $entry} = $value;
                $highlights[$offset - 1]{'start'} = $_->{'start'} if $highlights[$offset - 1]{'start'} > $_->{'start'};
                $highlights[$offset - 1]{'end'}   = $_->{'end'}   if $highlights[$offset - 1]{'end'}   < $_->{'end'};
              }
              
              push @{$highlights[$offset - 1]{'hrefs'}},    $_->{'href'}    || ();
              push @{$highlights[$offset - 1]{'html_ids'}}, $_->{'html_id'} || ();
              
              # Deal with colour aggregation
              if ($aggregate_colour) {
                $is_aggregated = 1 if $_->{'col'} eq $aggregate_colour;
                $highlights[$offset - 1]{'col'} = $aggregate_colour if $is_aggregated;
              }
              else {
                ## Keep track of all colours used in this bin
                my @rgb = $colourmap->rgb_by_name($_->{'col'});
                $highlights[$offset - 1]{'bin_colour'}{$_->{'col'}}{'rgb'} = \@rgb;
                $highlights[$offset - 1]{'bin_colour'}{$_->{'col'}}{'freq'}++;
              }
            } else {
              push @{$_->{'hrefs'}},    $_->{'href'}    || ();
              push @{$_->{'html_ids'}}, $_->{'html_id'} || ();
              push @highlights, $_;
              
              $bin_flag[$bin_id] = @highlights;
              $is_aggregated     = 0;
            }
          }
        }
        
        # Now we render the points
        my $high_flag    = 'l';
        my @starts       = map { $_->{'start'} } @highlights;
        my @sorting_keys = sort { $starts[$a] <=> $starts[$b] } 0..$#starts;
        my @flags        = ();
        my $flag         = 'l';
           $flags[$_]    = $flag = $flag eq 'l' ? 'r' : 'l' for @sorting_keys;
        
        foreach (@highlights) {
          my $start = $v_offset + $_->{'start'};
          my $end   = $v_offset + $_->{'end'};

          if ($highlight_style eq 'arrow') {
            $high_flag = shift @flags;
            $type      = "highlight_${high_flag}h$highlight_style";
          }
         
          ## set commonest and lightest colour as aggregate
          my $bc = $_->{'bin_colour'} || {};
          my (@top_colours, $freq);
          foreach my $colour (sort { $bc->{$b}{'freq'} <=> $bc->{$a}{'freq'} } keys %$bc) {
            last if $freq && $bc->{$colour}{'freq'} < $freq; 
            push @top_colours, $colour;
            $freq = $bc->{$colour}{'freq'};
          }
          if (scalar @top_colours > 1) {
            my @sorted = sort { sum(@{$bc->{$b}{'rgb'}}) <=> sum(@{$bc->{$a}{'rgb'}}) } @top_colours;
            $_->{'col'} = $sorted[0]; 
          }
          elsif (scalar @top_colours == 1) {
            $_->{'col'} = $top_colours[0];
          }
 
          # dynamic require of the right type of renderer
          if ($self->can($type)) {
            my ($href, %queries);
            
            foreach (@{$_->{'hrefs'} || []}) {
              my ($url, $query) = split /\?/;
              my %params      = map { split /=/ } split /;/, $query;
              
              foreach (keys %params) {
                push @{$queries{$_}}, $queries{'_last'}{$_} eq $params{$_} ? '' : $params{$_};
                $queries{'_last'}{$_} = $params{$_};
              }
              
              $href ||= "$url?";
            }
            
            delete $queries{'_last'};
            
            foreach my $param (sort keys %queries) {
              if (scalar(grep $_, @{$queries{$param}}) == 1) {
                $href .= "$param=$queries{$param}[0];";
              } else {
                $href .= sprintf '%s=%s;', $param, join ',', grep { $_ ne '' } @{$queries{$param}};
              }
            }
            
            $href =~ s/;$//;
            
            $self->push($self->$type({
              chr      => $chr,
              start    => $start,
              end      => $end,
              mid      => ($start + $end) / 2,
              h_offset => $h_offset,
              wid      => $wid,
              padding  => $padding,
              padding2 => $padding * $bpperpx * sqrt(3) / 2,
              id       => $_->{'id'},
              html_id  => join(', .', @{$_->{'html_ids'}}),
              href     => $href || $_->{'href'},
              col      => $_->{'col'},
              strand   => $_->{'strand'},
            }));
          }
        }
      }
    }
  }
  
  $self->minx($v_offset);
  
  return;
}

1;
