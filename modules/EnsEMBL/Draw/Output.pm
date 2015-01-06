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
use warnings;

use Carp;
use GD;
use GD::Simple;
use URI::Escape qw(uri_escape);
use POSIX qw(floor ceil);
use List::Util qw(min max);

use EnsEMBL::Web::Utils::RandomString qw(random_string);

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

#### BASIC ACCESSORS #################

sub image_config {
  my $self = shift;
  return $self->{'image_config'};
}

sub track_config {
  my $self = shift;
  return $self->{'track_config'};
}

sub strand {
  my $self = shift;
  return $self->{'strand'};
}

sub cache {
  my ($self, $key, $value) = @_;
  return unless $key;
  $self->{'image_config'}{'_cache'}{$key} = $value if $value;
  return $self->{'image_config'}{'_cache'}{$key};
}

#### DRAWING THE TRACK ####################

sub add_glyphs {
  my ($self, @glyphs) = @_;
  my ($gx, $gx1, $gy, $gy1);
    
  foreach (@glyphs) { 
    push @{$self->{'glyphs'}}, $_;

    $gx  = $_->x() || 0;
    $gx1 = $gx + ($_->width() || 0); 
    $gy  = $_->y() || 0;
    $gy1 = $gy + ($_->height() || 0);
    
    ## track max and min dimensions
    $self->minx($gx)  unless defined $self->minx && $self->minx < $gx;
    $self->maxx($gx1) unless defined $self->maxx && $self->maxx > $gx1;
    $self->miny($gy)  unless defined $self->miny && $self->miny < $gy;
    $self->maxy($gy1) unless defined $self->maxy && $self->maxy > $gy1;
  }  
}

sub render {
### Stub
### Render data into a track
  my $self = shift;
  warn "!!! RENDERING NOT IMPLEMENTED IN ".ref($self);
};

#### Manage overall dimensions ####################

sub minx {
  my ($self, $minx) = @_;
  $self->{'minx'} = $minx if(defined $minx);
  return $self->{'minx'};
}

sub miny {
  my ($self, $miny) = @_;
  $self->{'miny'} = $miny if(defined $miny);
  return $self->{'miny'};
}

sub maxx {
  my ($self, $maxx) = @_;
  $self->{'maxx'} = $maxx if(defined $maxx);
  return $self->{'maxx'};
}

sub maxy {
  my ($self, $maxy) = @_;
  $self->{'maxy'} = $maxy if(defined $maxy);
  return $self->{'maxy'};
};

sub height {
  my $self = @_;
  return int(abs($self->output->maxy - $self->output->miny) + 0.5);
}

sub width {
  my $self = @_;
  return abs($self->output->maxx - $self->output->minx);
}

sub length {
  my $self = shift;
  return scalar @{$self->{'glyphs'}};
}

sub convert_to_local {
### Convert genomic/feature coordinates to ones relative to this image
  my ($self, $start, $end) = @_;
  my $absolute_start = $self->{'container'}->start;
  $start = $start - $absolute_start;
  $end   = $end ? $end - $absolute_start : undef;
  return ($start, $end);
}

#### Labels and stuff #######################

sub error {
  my $self = shift;
  $self->{'error'} = @_ if @_;
  return $self->{'error'};
}

sub error_track_name {
  my $self = shift;
  return $self->track_config->get('caption');
}

sub label {
  my ($self, $text) = @_;
  $self->{'label'} = $text if(defined $text);
  return $self->{'label'};
}

sub label_img {
  my ($self, $text) = @_;
  $self->{'label_img'} = $text if(defined $text);
  return $self->{'label_img'};
}

sub label_text {
  my $self = shift;
  return join(' ',map { $_->{'text'} } @{$self->_label_glyphs});
}

sub max_label_rows { 
  my $self = shift;
  return $self->track_config->get('max_label_rows') || 1; 
}

sub recast_label {
  # XXX we should see which of these args are used and also pass as hash
  my ($self, $pixperbp, $width, $rows, $text, $font, $ptsize, $colour) = @_;

  my $caption = $self->output->my_label_caption;
  $text = $caption if $caption;

  my $n = 0;
  my ($ov,$text_out);
  ($rows,$text_out,$ov) = $self->_split_label($text,$width,$font,$ptsize,0);
  if($ov and $text =~ /\t[<>]/) {
    $text.="\t<" unless $text =~ /\t[<>]/;
    $text =~ s/\t>./...\t>/;
    $text =~ s/.\t</\t<.../;
    my $ov = 1;
    my $text_out;
    my $known_good = length $text;
    my $known_bad = 0;
    my $good_rows;
    foreach my $step ((5,2,1)) {
      my $n = $known_bad + $step;
      while($n<$known_good) {
        ($rows,$text_out,$ov) = $self->_split_label($text,$width,$font,$ptsize,$n);
        if($ov) { $known_bad = $n; }
        else    { $known_good = $n; $good_rows = $rows; }
        $n += $step;
      }
    }
    $rows = $good_rows;

  }

  my $max_width = max(map { $_->[1] } @$rows);

  my $composite = $self->createComposite({
    halign => 'left',
    absolutex => 1,
    absolutewidth => 1,
    width => $max_width,
    x => 0,
    y => 0,
    class     => $self->label->{'class'},
    alt       => $self->label->{'alt'},
    hover     => $self->label->{'hover'},
  });

  my $y = 0;
  my $h = $self->track_config->get('caption_height') || $self->label->{'height'};
  foreach my $row_data (@$rows) {
    my ($row_text,$row_width) = @$row_data;
    next unless $row_text;
    my $pad = 0;
    $pad = 4 if !$y and @$rows>1;
    my $row = $self->Text({
      font => $font,
      ptsize => $ptsize,
      text => $row_text,
      height => $h + $pad,
      colour    => $colour,
      y => $y,
      width => $max_width,
      halign => 'left',
    });
    $composite->push($row);
    $y += $h + $pad; # The 4 is to add some extra delimiting margin
  }
  $self->label($composite);
}

sub _label_glyphs {
  my $self = CORE::shift;
  my $label = $self->label;
  return [] unless $label;

  my $glyphs = [$label];
  if ($label->can('glyphs')) {
    $glyphs = [ $self->{'label'}->glyphs ];
  }
  return $glyphs;
}

sub _split_label {
### Text wrapping is a job for the human eye. We do the best we can:
### wrap on word boundaries but don't have <6 trailing characters.
  my ($self, $text, $width, $font, $ptsize, $chop) = @_;

  for (1..$chop) {
    $text =~ s/.\t</\t</;
    $text =~ s/\t>./\t>/;
  }
  $text =~ s/\t[<>]//;
  my $max_rows = $self->max_label_rows;
  my @words = split(/(?<=[ \-\._])/,$text);
  while(@words > 1 and length($words[-1]) < 6) {
    my $tail = pop @words;
    $words[-1] .= $tail;
  }
  my @split;
  my $line_so_far = '';

  foreach my $word (@words) {
    my $candidate_line = $line_so_far.$word;
    my $replacement_line = $candidate_line;
    $candidate_line =~ s/^ +//;
    $candidate_line =~ s/ +$//;
    my @res = $self->get_text_width(undef, $candidate_line, '', font => $font, ptsize => $ptsize);
    if(!@split or $res[2] > $width) { # CR
      if(@split == $max_rows) { # No room!
        my @res = $self->get_text_width($width, $candidate_line, '', ellipsis => 1, font => $font, ptsize => $ptsize);
        $split[-1][0] = $res[0];
        $split[-1][1] = $res[2];
        return (\@split,$text,1);
        last;
      }
      my @res = $self->get_text_width($width, $word, '', ellipsis => 1, font => $font, ptsize => $ptsize);
      $line_so_far = $res[0];
      push @split,[$line_so_far,$res[2]];
    } else {
      $line_so_far = $replacement_line;
      $split[-1][0] = $line_so_far;
      $split[-1][1] = $res[2];
    }
  }
  return (\@split, $text, 0);
}


sub my_label_caption {
}

sub init_label {
  my $self = shift;

  return $self->label(undef) if defined $self->{'image_config'}->{'_no_label'};

  my $text = $self->track_config->get('caption');

  my $img = $self->track_config->get('caption_img');
  if($img and $img =~ s/^r:// and $self->{'strand'} ==  1) { $img = undef; }
  if($img and $img =~ s/^f:// and $self->{'strand'} == -1) { $img = undef; }

  return $self->label(undef) unless $text;

  my $image_config  = $self->{'image_config'};
  my $track_config  = $self->{'track_config'};
  my $hub           = $image_config->hub;
  my $track_id      = $track_config->get('id');
  my $name          = $track_config->get('name');
  my $desc          = $track_config->get('description');
  my $style         = $image_config->species_defs->ENSEMBL_STYLE;
  my $font          = $style->{'GRAPHIC_FONT'};
  my $fsze          = $style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'};
  my @res           = $self->get_text_width(0, $text, '', font => $font, ptsize => $fsze);
  my $component     = $image_config->get_parameter('component');
  my $hover         = $component && !$hub->param('export') && $track_config->get('menu') ne 'no';
  my $class         = random_string(8);

  if ($hover) {
    my $fav       = $image_config->get_favourite_tracks->{$track_id};
    my @renderers = grep !/default/i, @{$track_config->get('renderers') || []};
    my $subset    = $track_config->get('subset');
    my @r;

    my $url = $hub->url('Config', {
      species  => $image_config->species,
      action   => $component,
      function => undef,
      submit   => 1
    });

    if (scalar @renderers > 4) {
      while (my ($val, $text) = splice @renderers, 0, 2) {
        push @r, { url => "$url;$track_id=$val", val => $val, text => $text, current => $val eq $self->{'display'} };
      }
    }

    $image_config->{'hover_labels'}->{$class} = {
      header    => $name,
      desc      => $desc,
      class     => "$class $track_id",
      component => lc($component . ($image_config->multi_species && $image_config->species ne $hub->species ? '_' . $image_config->species : '')),
      renderers => \@r,
      fav       => [ $fav, "$url;$track_id=favourite_" ],
      off       => "$url;$track_id=off",
      conf_url  => $self->species eq $hub->species ? $hub->url($hub->multi_params) . ";$image_config->{'type'}=$track_id=$self->{'display'}" : '',
      subset    => $subset ? [ $subset, $hub->url('Config', { species => $image_config->species, action => $component, function => undef, __clear => 1 }), lc "modal_config_$component" ] : '',
    };
  }

  my $ch = $self->track_config->get('caption_height') || 0;
  ## Draw label
  $self->label($self->createGlyph({
    text      => $text,
    font      => $font,
    ptsize    => $fsze,
    colour    => $self->{'label_colour'} || 'black',
    absolutey => 1,
    height    => $ch || $res[3],
    class     => "label $class",
    alt       => $name,
    hover     => $hover,
  }));

  if($img) {
    $img =~ s/^([\d@-]+)://; my $size = $1 || 16;
    my $offset = 0;
    $offset = $1 if $size =~ s/@(-?\d+)$//;
    $self->label_img($self->Sprite({
        z             => 1000,
        x             => 0,
        y             => $offset,
        sprite        => $img,
        spritelib     => 'species',
        width         => $size,
        height         => $size,
        absolutex     => 1,
        absolutey     => 1,
        absolutewidth => 1,
        pixperbp      => 1,
        alt           => '',
    }));
  }
}

sub label {
  my ($self, $text) = @_;
  $self->{'label'} = $text if(defined $text);
  return $self->{'label'};
}

sub label_img {
  my ($self, $text) = @_;
  $self->{'label_img'} = $text if(defined $text);
  return $self->{'label_img'};
}

sub label_text {
  my $self = shift;
  return join(' ',map { $_->{'text'} } @{$self->_label_glyphs});
}

sub max_label_rows {
  my $self = shift;
  return $self->track_config->get('max_label_rows') || 1;
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
    push @{$self->{'tags'}{$tag}}, {
      %$x_pos,
      'glyph' => $glyph
    };
  } else {
    push @{$self->{'tags'}{$tag}}, {
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

sub default_height { return 8; }

sub track_width {
  my $self = shift;
  return $self->{'container'}{'track_width'};
}

sub scalex { 
  my $self = shift;
  return $self->{'config'}{'transform'}{'scalex'};
} 

### Wrappers around low-level drawing code

sub createGlyph { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph->new(@_);     
}

sub createCircle { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Circle->new(@_);     
}

sub createComposite { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Composite->new(@_);     
}

sub createPoly { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Poly->new(@_);     
}

sub createTriangle { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Triangle->new(@_);     
}

#### Drawing-related code from GlyphSet ####

sub get_text_width {
  my ($self, $width, $text, $short_text, %parameters) = @_;

  ## Adjust the text for courier fonts
  $text = 'X' if length $text == 1 && $parameters{'font'} =~ /Cour/i;

  ## Look in the cache for a previous entry
  my $key  = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}";
  my $cached = $self->cache($key);
  return @{$cached} if ($cached && ref($cached) eq 'ARRAY');

  my $gd = $self->get_gd($parameters{'font'}, $parameters{'ptsize'});

  return unless $gd;

  # Use the text object to determine height/width of the given text;
  $width ||= 1e6; # Make initial width very big by default

  my ($w, $h) = $gd->stringBounds($text);
  my @res;

  if ($w < $width) {
    @res = ($text, 'full', $w, $h);
  } elsif ($short_text) {
    ($w, $h) = $gd->stringBounds($text);
    @res = $w < $width ? ($short_text, 'short', $w, $h) : ('', 'none', 0, 0);
  } elsif ($parameters{'ellipsis'}) {
    my $string = $text;

    while ($string) {
      chop $string;

      ($w, $h) = $gd->stringBounds("$string...");

      if ($w < $width) {
        @res = ("$string...", 'truncated', $w, $h);
        last;
      }
    }
  } else {
    @res = ('', 'none', 0, 0);
  }

  $self->cache($key, \@res); # Update the cache

  return @res;
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

  return $self->cache($font_key) if $self->cache($font_key);

  my $fontpath = $self->{'image_config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}. "$font.ttf";
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

  return $self->cache($font_key, $gd); # Update font cache
}


1;

