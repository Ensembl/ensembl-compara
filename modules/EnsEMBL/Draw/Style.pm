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

package EnsEMBL::Draw::Style;

=head2
  Description: Base package for drawing a track in a particular style - this replaces 
               much of the rendering code within a glyphset

EXAMPLE

use EnsEMBL::Draw::Style::NameOfStyle;

sub render_normal {
...
    my $config = $self->track_style_config;
    my $data = [];
    # Munge data
    my $style = EnsEMBL::Draw::Style::NameOfStyle->new($config, $data);
    $self->push($style->glyphs);
}

Note that there are three main types of Style:

1. Feature: individual features aligned to the genome. The track depth depends on the number of features
            in a given location and the depth of the chosen display setting

2. Graph:   scored data that could be displayed as a continuous line or bar chart. The track depth is normally fixed

3. Plot:    scatter plots, i.e. point data with both an x axis (position on genome) and a y axis (score or similar). 
            Could be considered a type of graph, but is distinct enough to warrant a separate namespace

=cut 

use strict;
use warnings;
no warnings 'uninitialized';

use POSIX qw(ceil);
use List::Util qw(min max);

use EnsEMBL::Draw::Utils::Bump qw(bump);
use EnsEMBL::Draw::Utils::Text;
use EnsEMBL::Draw::Utils::ColourMap;
use EnsEMBL::Draw::Utils::LocalCache;

use EnsEMBL::Draw::Glyph::Arc;
use EnsEMBL::Draw::Glyph::Barcode;
use EnsEMBL::Draw::Glyph::Circle;
use EnsEMBL::Draw::Glyph::Composite;
use EnsEMBL::Draw::Glyph::Histogram;
use EnsEMBL::Draw::Glyph::Intron;
use EnsEMBL::Draw::Glyph::Line;
use EnsEMBL::Draw::Glyph::Poly;
use EnsEMBL::Draw::Glyph::Triangle;
use EnsEMBL::Draw::Glyph::Rect;
use EnsEMBL::Draw::Glyph::Space;
use EnsEMBL::Draw::Glyph::Sprite;
use EnsEMBL::Draw::Glyph::Text;

sub rainbow {
## Enable drawing of features in different colours so they can be told apart
## (Generally only used for debugging)
## @param index - Integer (optional)
## Usage: 
## my $debug = $self->track_config->get('DEBUG_RAINBOW');
## $feature->{'colour'} = $self->random_colour if $debug;
  my ($self, $index) = @_;
  my $rainbow = $self->image_config->hub->species_defs->RAINBOW || [qw(magenta red orange yellow green cyan blue purple)];
  if (defined $index) {
    ## Use the supplied index but adjust to fit within the array
    if ($index > scalar(@$rainbow)) {
      $index = $index % scalar(@$rainbow);
    }
  }
  else {
    ## Return a random colour 
    $index = rand() * scalar(@$rainbow);
  }
  return $rainbow->[$index];  
}

### Wrappers around low-level drawing code
sub Arc        { my $self = shift; return EnsEMBL::Draw::Glyph::Arc->new(@_);        }
sub Barcode    { my $self = shift; return EnsEMBL::Draw::Glyph::Barcode->new(@_);    }
sub Circle     { my $self = shift; return EnsEMBL::Draw::Glyph::Circle->new(@_);     }
sub Composite  { my $self = shift; return EnsEMBL::Draw::Glyph::Composite->new(@_);  }
sub Histogram  { my $self = shift; return EnsEMBL::Draw::Glyph::Histogram->new(@_);    }
sub Intron     { my $self = shift; return EnsEMBL::Draw::Glyph::Intron->new(@_);     }
sub Line       { my $self = shift; return EnsEMBL::Draw::Glyph::Line->new(@_);       }
sub Poly       { my $self = shift; return EnsEMBL::Draw::Glyph::Poly->new(@_);       }
sub Rect       { my $self = shift; return EnsEMBL::Draw::Glyph::Rect->new(@_);       }
sub Space      { my $self = shift; return EnsEMBL::Draw::Glyph::Space->new(@_);      }
sub Sprite     { my $self = shift; return EnsEMBL::Draw::Glyph::Sprite->new(@_);     }
sub Text       { my $self = shift; return EnsEMBL::Draw::Glyph::Text->new(@_);       }
sub Triangle   { my $self = shift; return EnsEMBL::Draw::Glyph::Triangle->new(@_);   }


sub new {
  my ($class, $config, $data) = @_;

  my $cache = $config->{'image_config'}->hub->cache || new EnsEMBL::Draw::Utils::LocalCache;

  my $colourmap = new EnsEMBL::Draw::Utils::ColourMap($config->{'image_config'}->hub->species_defs);

  my $self = {
              'data'        => $data,
              'cache'       => $cache,
              'colourmap'   => $colourmap,
              'glyphs'      => [],
              'connections' => [],
              %$config
              };

  bless $self, $class;

  my @text_info = $self->get_text_info;
  $self->{'label_height'} = $text_info[3];

  $self->{'bump_tally'} = {'_bump' => {
                                    'length' => $self->image_config->container_width,
                                    'rows'   => $self->track_config->get('depth') || 1e3,
                                    'array'  => [],
                                      }
                            }; 

  return $self;
}

sub colourmap {
  my $self = shift;
  return $self->{'colourmap'};
}

sub connections {
  my $self = shift;
  return $self->{'connections'};
}

sub create_glyphs {
### Method to create the glyphs needed by a given style
### Returns an array of Glyph objects
### Stub - must be implemented in child modules
  my $self = shift;
  warn "!!! MANDATORY METHOD ".ref($self).'::create_glyphs HAS NOT BEEN IMPLEMENTED!';
}

sub draw_hidden_bgd {
  my ($self, $height) = @_;

  while (my($y, $link) = each (%{$self->{'bg_href'}||{}})) {
    push @{$self->glyphs}, $self->Rect({
                                        x         => 0,
                                        y         => $y,
                                        width     => $self->image_config->container_width,
                                        height    => $height,
                                        absolutey => 1,
                                        href      => $link,
                                        class     => 'group',
                                        });
  }
}

sub draw_graph_base {
### Axes, guidelines, etc used by Graph and Plot styles
  my ($self, $metadata) = @_;
  return if ref $self =~ /Feature/;

  ## Set some track-wide variables
  my $track_config    = $self->track_config;
  my $row_height      = $track_config->get('height') || 60;
  my $slice_width     = $self->image_config->container_width;

  ## LOTS OF POSITIONAL MATHS!

  # max_score: score at top of y-axis on graph
  # min_score: score at bottom of y-axis on graph
  # range: scores spanned by graph (small value used if identically zero)
  # pix_per_score: vertical pixels per unit score
  my $min_score     = defined($metadata->{'min_score'})
                          ? $metadata->{'min_score'} : $track_config->get('min_score');
  my $max_score     = defined($metadata->{'max_score'})
                          ? $metadata->{'max_score'} : $track_config->get('max_score');
  my $baseline_zero = defined($metadata->{'baseline_zero'})
                          ? $metadata->{'baseline_zero'} : $track_config->get('baseline_zero');

  my $range; 
  if (defined($metadata->{'y_min'}) || defined($metadata->{'y_max'})) {
    ## User has defined scale, so use it!
    my ($saved_min, $saved_max) = ($min_score, $max_score);
    $min_score = $metadata->{'y_min'} if (defined($metadata->{'y_min'}) && $metadata->{'y_min'} ne ''); 
    $max_score = $metadata->{'y_max'} if (defined($metadata->{'y_max'}) && $metadata->{'y_max'} ne ''); 
    ## Sanity check - ignore these values if user settings are nonsense
    $range = (defined ($max_score) && defined ($min_score)) ? $max_score - $min_score : 0;
    if ($range == 0) {
      $min_score = $saved_min;
      $max_score = $saved_max;
    }
  }
  else {
    $range = $max_score - $min_score;
    ## Try to calculate something sensible 
    if ($range < 0.01) {
      ## Oh dear, data all has pretty much same value ...
      if ($max_score > 0.01) {
        ## ... but it's not zero, so just move minimum down
        $min_score = 0;
      } 
      else {
        ## ... just create some sky
        $max_score = 0.1;
        $metadata->{'y_max'} = $max_score;
      }
    }
    $min_score = 0 if $min_score >= 0 && $baseline_zero;
  }
  $range = $max_score - $min_score;
  ## Avoid divide-by-zero errors
  $range = 1 if !$range;

  my $pix_per_score = $row_height/$range;
  $self->track_config->set('pix_per_score', $pix_per_score);

  ## top: top of graph in pixel units, offset from track top (usu. 0)
  ## line_score: value to draw "to" up/down, in score units (usu. 0)
  ## line_px: value to draw "to" up/down, in pixel units (usu. 0)
  ## bottom: bottom of graph in pixel units (usu. approx. pixel height)
  my $top = $track_config->get('initial_offset') || 0;
  ## Reset offset for subsequent tracks
  $track_config->set('initial_offset', $top + $row_height + 20);
  my $line_score = max(0, $min_score);
  my $bottom = $top + $pix_per_score * $range;
  my $line_px = $bottom - ($line_score - $min_score) * $pix_per_score;

  ## Extra left-legend stuff
  if ($track_config->get('labels')) {
    $self->add_minilabel($top);
  }

  ## Draw axes and their numerical labels
  unless ($track_config->get('no_axis')) {
    $self->draw_axes($top, $line_px, $bottom, $slice_width);
    if ($track_config->get('axis_label') ne 'off') {
      $self->draw_score($top, $max_score);
      $self->draw_score($bottom, $min_score);

      ## Shift down the lhs label to between the axes
      my $label_y_offset;
      if ($bottom - $top > 30) {
        ## luxurious space for centred label
        $label_y_offset =  ($bottom - $top) / 2;  # half-way-between 
        ## graph is offset further if subtitled
        if ($track_config->get('wiggle_subtitle')) {
          ## two-line label so centre its centre
          $label_y_offset -= 1;
        }
      } else {
        ## tight, just squeeze it down a little
        $label_y_offset = 0;
      }
      ## Put this into track_config, so it can be passed back to GlyphSet
      $track_config->set('label_y_offset', $label_y_offset);
    }
  }

  ## Horizontal guidelines at 25% intervals
  ## Note that we assume these settings will be the same for all tracks
  if (!$track_config->get('no_axis') and !$track_config->get('no_guidelines')) {
    foreach my $i (1..4) {
      my $type;
      $type = 'small' unless $i % 2;
      $self->draw_guideline($slice_width, ($top * $i + $bottom * (4 - $i))/4, $type);
    }
  }

  ## Draw title over track
  if (!$track_config->get('hide_subtitle')) {
    $self->draw_subtitle($metadata, $top);
  }

  return {
          'min_score'       => $min_score,
          'max_score'       => $max_score,
          'line_score'      => $line_score,
          'line_px'         => $line_px,
          'pix_per_score'   => $pix_per_score,
        };
}

sub get_text_info {
### Get text dimensions
  my ($self, $text) = @_;
  $text ||= 'X';
  my @info = EnsEMBL::Draw::Utils::Text::get_text_info($self->cache, $self->image_config, 0, $text, '', font => $self->{'font_name'}, ptsize => $self->{'font_size'});
  return {'width' => $info[2], 'height' => $info[3]};
}

sub draw_subtitle {
  my ($self, $metadata, $top) = @_;
  $metadata ||= {};
  ## Track name actually gets precedence, which is a bit illogical but whatever...
  my $subtitle = $metadata->{'name'} || $metadata->{'subtitle'} 
                  || $self->track_config->get('subtitle')
                  || $self->track_config->get('caption');
  return unless $subtitle;

  my $subtitle_colour = $metadata->{'colour'} 
                          || $metadata->{'color'} 
                          || $self->track_config->get('colour') 
                          || 'slategray';
  my $subtitle_y      = defined($top) ? $top : $self->track_config->get('initial_offset') || 0;
  $subtitle_y        += $self->track_config->get('subtitle_y') if defined($self->track_config->get('subtitle_y'));
  my $height = 8;

  push @{$self->glyphs}, 
    $self->Text({
                  font      => 'Arial',
                  text      => $subtitle, 
                  ptsize    => 8,
                  height    => $height,
                  colour    => $subtitle_colour,
                  x         => 4,
                  y         => $subtitle_y,
                  halign    => 'left',
                  absolutex => 1,
                  absolutey => 1,
                });
  return $height;
}

sub make_readable {
### Darken pale text colours so that they can be read on a pale background
  my ($self, $colour) = @_;
  my $colourmap = $self->colourmap;
  my @rgb = $colourmap->rgb_by_name($colour);
  @rgb = $colourmap->hivis(2, @rgb);
  return join(',', @rgb);
}

sub make_contrasting {
### Make text white on dark colours, black on lighter ones
  my ($self, $colour) = @_;
  my $colourmap = $self->colourmap;
  my $contrast = $colourmap->contrast($colour);
  return $contrast;
}

sub centre_text {
  my ($self, $text) = @_;

  my $text_info   = $self->get_text_info($text);
  my $slice_width = $self->image_config->container_width;

  return ($slice_width - $text_info->{'width'}) / 2;
}

sub set_bump_row {
  my ($self, $start, $end, $show_label, $text_info) = @_;
  my $row = 0;

  ## Set bumping based on longest of feature and label
  ## FIXME Hack adds 20% to text width, because GD seems to be
  ## consistently underestimating the true width of the label
  my $text_end  = $show_label ?
                        ceil($start + $text_info->{'width'} * 1.2 / $self->{'pix_per_bp'})
                        : 0;
  $end          = $text_end if $text_end > $end;

  $row = bump($self->bump_tally, $start, $end);
  return $row;
}

sub add_messages {
### Add messages below a track
  my ($self, $metadata, $y) = @_;
  my @messages;
 
  ## Non-rendered feature count 
  if ($metadata->{'not_drawn'}) {
    my $name    = $metadata->{'name'} || $self->track_config->get('name');
    my $message = sprintf('%s feature', $metadata->{'not_drawn'});
    $message   .= 's' if $metadata->{'not_drawn'} > 1;
    $message   .= sprintf(" from '%s'", $name) if $name;
    $message   .= ' not shown';
    push @messages, $message;
  }
 
  ## Now draw them all
  $y += 4; ## Add a bit of space at the top
 
  foreach (@messages) {
    my $x = $self->centre_text($_);
    push @{$self->glyphs}, $self->Text({
                font      => $self->{'font_name'},
                colour    => $metadata->{'message_colour'} || 'red',
                height    => $self->{'font_size'},
                ptsize    => $self->{'font_size'},
                text      => $_,
                x         => $x,
                y         => $y,
    });
    $y += $self->{'font_size'} + 2;
  }
}

sub add_connection {
  my ($self, $glyph, $tag, $params) = @_;
  push @{$self->{'connections'}}, {'glyph' => $glyph, 'tag' => $tag, 'params' => $params};
}

#### TRIGONOMETRY FOR CIRCULAR GLYPHS

sub truncate_ellipse {
  my ($self, $x, $a, $b) = @_;
  my $h = $self->ellipse_y($x, $a, $b);
  return $self->atan_in_degrees($x, $h);
}

sub ellipse_y {
  my ($self, $x, $a, $b) = @_;
  my $y = sqrt(abs((1 - (($x * $x) / ($a * $a))) * $b * $b));
  return int($y);
}

sub atan_in_degrees {
  my ($self, $x, $y) = @_;
  my $pi   = 4 * atan2(1, 1);
  my $atan = atan2($y, $x);
  return int($atan * (180 / $pi));
}


#### BASIC ACCESSORS #################

sub glyphs {
### Accessor
### @return ArrayRef of EnsEMBL::Draw::Glyph objects 
  my $self = shift;
  return $self->{'glyphs'};
}

sub data {
### Accessor
### @return ArrayRef containing the feature(s) to be drawn 
  my $self = shift;
  return $self->{'data'};
}

sub image_config {
### Accessor
### @return the ImageConfig object belonging to the track
  my $self = shift;
  return $self->{'image_config'};
}

sub track_config {
### Accessor
### @return the menu Node object which contains the track configuration
  my $self = shift;
  return $self->{'track_config'};
}

sub bump_tally {
### Accessor
### @return a Hashref that keeps track of bumping 
  my $self = shift;
  return $self->{'bump_tally'};
}

sub strand {
### Accessor
### @return The strand on which we are drawing this set of glyphs
  my $self = shift;
  return $self->{'strand'};
}

sub cache {
### Accessor 
### @return object - either EnsEMBL::Web::Cache or EnsEMBL::Draw::Utils::LocalCache 
  my $self = shift;
  return $self->{'cache'};
}

1;
