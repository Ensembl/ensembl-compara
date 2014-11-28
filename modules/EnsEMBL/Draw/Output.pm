=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Output;

### Base package for drawing a discreet section of a genomic image,
### such as a section of assembly, feature track, scalebar or track legend
### Uses GD and the EnsEMBL::Draw::Glyph codebase to render data that's 
### been passed in from a controller

use strict;

use Carp;
use GD;
use GD::Simple;
use URI::Escape qw(uri_escape);
use POSIX qw(floor ceil);
use List::Util qw(min max);

use EnsEMBL::Draw::Glyph;
use EnsEMBL::Draw::Glyph::Circle;
use EnsEMBL::Draw::Glyph::Composite;
use EnsEMBL::Draw::Glyph::Poly;
use EnsEMBL::Draw::Glyph::Triangle;

use parent qw(EnsEMBL::Root);

sub new {
  my ($class, $config, $data) = @_;

  my $self = {
              'data' => $data,
              %$config
              };

  bless $self, $class;

  return $self;
}

sub render {
### Stub
### Render data into a track
  my $self = shift;
  warn "!!! RENDERING NOT IMPLEMENTED IN ".ref($self);
};

sub convert_to_local {
### Convert genomic/feature coordinates to ones relative to this image
  my ($self, $start, $end) = @_;
  my $absolute_start = $self->{'container'}->start;
  $start = $start - $absolute_start;
  $end   = $end ? $end - $absolute_start : undef;
  return ($start, $end);
}

sub draw_cigar_feature {
### Generic method currently used by several GlyphSets, though it may
### not need to live in here permanently
  my ($self, $params) = @_;

  my $feature   = $params->{'feature'};
  my $composite = $params->{'composite'};
  my $h         = $params->{'height'};
  my $inverted  = $params->{'inverted'} || 0;
  my $width     = $self->{'container'}->length;

  my $match_colour = $params->{'feature_colour'};
  if($inverted) {
    # Wash out matches when mismatches are to be emphasised
    $match_colour = $self->{'config'}->colourmap->mix($match_colour,'white',0.9);
  }

  my $strand      = $self->strand;
  my $fstrand     = $feature->{'strand'};
  my $hstrand     = $feature->{'hstrand'};
  my $start       = $feature->{'start'};
  my $hstart      = $feature->{'hstart'};
  my $hend        = $feature->{'hend'};
  my $slice_start = $feature->{'slice_start'};
  my $slice_end   = $feature->{'slice_end'};
  my $tag1        = $feature->{'tag1'};
  my $tag2        = $feature->{'tag2'}; 
  my @delete;

  # Parse the cigar string, splitting up into an array
  # like ('10M','2I','30M','I','M','20M','2D','2020M');
  # original string - "10M2I30MIM20M2D2020M"
  my @cigar = $feature->{'cigar_string'} =~ /(\d*[MDImUXS=])/g;
  @cigar    = reverse @cigar if $fstrand == -1;

  my $last_e = -1;
  foreach (@cigar) {
    # Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
    # representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    # If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l, $type) = /^(\d+)([MDImUXS=])/ ? ($1, $2) : (1, $_);

    # If it is a D (this is a deletion) and so we note it as a feature between the end
    # of the current and the start of the next feature (current start, current start - ORIENTATION)
    # otherwise it is an insertion or match/mismatch
    # we compute next start sa (current start, next start - ORIENTATION) 
    # next start is current start + (length of sub-feature) * ORIENTATION 
    my $s = $start;
    my $e = ($start += ($type eq 'D' ? 0 : $l)) - 1;

    my $s1 = $fstrand == 1 ? $slice_start + $s - 1 : $slice_end - $e + 1;
    my $e1 = $fstrand == 1 ? $slice_start + $e - 1 : $slice_end - $s + 1;

    my ($hs, $he);

    if ($fstrand == 1) {
      $hs = $hstart;
      $he = ($hstart += ($type eq 'I' ? 0 : $l)) - 1;
    } else {
      $he = $hend;
      $hs = ($hend -= ($type eq 'I' ? 0 : $l)) + 1;
    }

    # If a match/mismatch - draw box
    if ($type =~ /^[MmU=X]$/) {
      ($s, $e) = ($e, $s) if $s > $e; # Sort out flipped features

      next if $e < 1 || $s > $width; # Skip if all outside the box

      $s = 1       if $s < 1;         # Trim to area of box
      $e = $width if $e > $width;

      ## Coloured rectangle
      my $box = $self->create_Glyph({
        x         => $s - 1,
        y         => $params->{'y'} || 0,
        width     => $e - $s + 1,
        height    => $h,
        colour    => $match_colour,
      });

      if ($params->{'link'}) {
        my $tag = $strand == 1 ? "$tag1:$s1:$e1#$tag2:$hs:$he" : "$tag2:$hs:$he#$tag1:$s1:$e1";
        my $x;

        if ($params->{'other_ori'} == $hstrand && $params->{'other_ori'} == 1) {
          $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
        } else {
          $x = $strand == -1 ? 1 : 0;
        }

        $x ||= 1 if $fstrand == 1 && $hstrand * $params->{'other_ori'} == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join

        $self->join_tag($box, $tag, {
          x     => $x,
          y     => $strand == -1 ? 1 : 0 + ($params->{'y'} || 0),
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });

        $self->join_tag($box, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0 + ($params->{'y'} || 0),
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
      }

      $composite->push($box);

      if($inverted && $last_e != -1) {
        $composite->push($self->create_Glyph({
          x         => $last_e,
          y         => $params->{'y'} || 0,
          width     => $s - $last_e + 1,
          height    => $h,
          colour    => $params->{'feature_colour'},
        }));

      }
      $last_e = $e;

    } elsif ($type eq 'D') { # If a deletion temp store it so that we can draw after all matches
      ($s, $e) = ($e, $s) if $s < $e;

      next if $e < 1 || $s > $width;  # Skip if all outside box

      push @delete, $e;
    }
  }

  # Draw deletion markers
  foreach (@delete) {
    $composite->push($self->create_Glyph({
      x         => $_,
      y         => $params->{'y'} || 0,
      width     => 0,
      height    => $h,
      colour    => $params->{'delete_colour'},
      absolutey => 1
    }));
  }
}

sub join_tag {
# join_tag joins between glyphsets in different tracks
#$self->join_tag(
#  $tglyph,     # A glyph you've drawn...
#  $key,      # Key for glyph
#  $T,        # X position in glyph (0-1)
#  0,         # Y position in glyph (0-1) 0 nearest contigs
#  $colour,     # colour to draw shape
#  'fill',      # whether to fill or draw line
#  -99        # z-index 
#);
  my ($self, $glyph, $tag, $x_pos, $y_pos, $col, $style, $zindex, $href, $alt, $class) = @_;

  if (ref $x_pos eq 'HASH') {
    CORE::push @{$self->{'tags'}{$tag}}, {
      %$x_pos,
      'glyph' => $glyph
    };
  } else {
    CORE::push @{$self->{'tags'}{$tag}}, {
      'glyph' => $glyph,
      'x'     => $x_pos,
      'y'     => $y_pos,
      'col'   => $col,
      'style' => $style,
      'z'     => $zindex,
      'href'  => $href,
      'alt'   => $alt,
      'class' => $class
    };
  }
}

######## MISCELLANEOUS ACCESSORS #################

sub cache {
  my $self = shift;
  return $self->{'config'}->hub->cache;
}

sub image_config {
  my $self = shift;
  return $self->{'config'};
}

sub track_config {
  my $self = shift;
  return $self->{'my_config'};
}

sub default_height { return 8; }

sub track_width {
  my $self = shift;
  return $self->{'container'}{'track_width'};
}

sub scalex { 
  my $self = shift;
  return $self->{'config'}->transform->{'scalex'};
} 

### Wrappers around low-level drawing code

sub create_Glyph { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph->new(@_);     
}

sub create_Circle { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Circle->new(@_);     
}

sub create_Composite { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Composite->new(@_);     
}

sub create_Poly { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Poly->new(@_);     
}

sub create_Triangle { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Triangle->new(@_);     
}

#### Bring in some basic drawing functionality from Sanger::Graphics

sub bump_row {
### Bumping code. 
### @param start Integer - start of the feature you want bumping 
### @param end Integer - end of the feature you want bumping
### @param length Integer - the length of the feature to bump against
### @param bit_arry ArrayRef - will be modified by this subroutine, to maintain persistence.
### @param max_row Integer (optional) - moximum number of rows to bump - defaults to 1e9
### @return row Integer - row number to which your feature has been bumped
  my ($start, $end, $bit_length, $bit_array, $max_row) = @_;
  $max_row  = 1e9 unless defined $max_row;
  my $row   = 0;
  my $len   = $end - $start + 1;

  if( $len <= 0 || $bit_length <= 0 ) {
    carp("We've got a bad length of $len or $bit_length from $start-$end in Bump. Probably you haven't flipped on a strand");
  }

  my $element = '0' x $bit_length;

  substr($element, $start, $len)='1' x $len;

  LOOP:{
    if($$bit_array[$row]) {
      if( ($bit_array->[$row] & $element) == 0 ) {
        $bit_array->[$row] = ($bit_array->[$row] | $element);
      } else {
        $row++;
        return $max_row + 10 if $row > $max_row;
        redo LOOP;
      }
  } else {
      $$bit_array[$row] = $element;
    }
  }
  return $row;
}

sub get_gd {
  ### Returns the GD::Simple object appropriate for the given fontname
  ### and fontsize. GD::Simple objects are cached against fontname and fontsize.

  my $self     = shift;
  my $font     = shift || 'Arial';
  my $ptsize   = shift || 10;
  my $font_key = "${font}--${ptsize}";

  return $self->cache->get($font_key) if $self->cache->get($font_key);

  my $fontpath = $self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}. "/$font.ttf";
  my $gd       = GD::Simple->new(400, 400);

  eval {
    if (-e $fontpath) {
      $gd->font($fontpath, $ptsize);
    } elsif ($font eq 'Tiny') {
      $gd->font(gdTinyFont);
    } elsif ($font eq 'MediumBold') {
      $gd->font(gdMediumBoldFont);
    } elsif ($font eq 'Large') {
      $gd->font(gdLargeFont);
    } elsif ($font eq 'Giant') {
      $gd->font(gdGiantFont);
    } else {
      $font = 'Small';
      $gd->font(gdSmallFont);
    }
  };

  warn $@ if $@;

  return $self->cache->get($font_key) = $gd; # Update font cache
}


1;

