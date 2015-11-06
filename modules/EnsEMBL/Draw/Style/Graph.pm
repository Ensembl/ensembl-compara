=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style::Graph;

=pod
Renders a track as a graph or continuous plot 

This module expects data in the following format:

  $data = [
          {'metadata' => {},
           'features'  => [
              {
              'start'         => 123456,
              'end'           => 123789,
              'colour'        => 'red',                             # mandatory unless bordercolour set
              'bordercolour'  => 'black',                           # optional
              'label'         => 'Feature 1',                       # optional
              'label_colour'  => 'red',                             # optional
              'href'          => '/Location/View?r=123456-124789',  # optional  
              'title'         => 'Some text goes here',             # optional  
              },
            ]},
          ];

Note that in order to support multiple subtracks within a glyphset (whether multi-wiggle or separate), we must pass an array of hashes with optional metadata for each subtrack 

=cut

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
### Create all the glyphs required by this style
### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data            = $self->data;
  my $image_config    = $self->image_config;
  my $track_config    = $self->track_config;

  ## Set some track-wide variables
  my $slice_width     = $image_config->container_width;
  my $row_height      = $track_config->get('height') || 60;

  foreach my $subtrack (@$data) {
    my $metadata        = $subtrack->{'metadata'} || {};

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
    my $range = $max_score - $min_score;
    if ($range < 0.01) {
      ## Oh dear, data all has pretty much same value ...
      if ($max_score > 0.01) {
        ## ... but it's not zero, so just move minimum down
        $min_score = 0;
      } else {
        ## ... just create some sky
        $max_score = 0.1;
      }
    }
    $min_score = 0 if $min_score >= 0 && $baseline_zero;
    $range = $max_score - $min_score;
    my $pix_per_score = $row_height/$range;

    ## top: top of graph in pixel units, offset from track top (usu. 0)
    ## line_score: value to draw "to" up/down, in score units (usu. 0)
    ## line_px: value to draw "to" up/down, in pixel units (usu. 0)
    ## bottom: bottom of graph in pixel units (usu. approx. pixel height)
    my $top = $track_config->get('initial_offset') || 0;
    ## Reset offset for subsequent tracks
    unless ($track_config->get('multiwiggle')) {
      $track_config->set('initial_offset', $top + $row_height + 20);
    }
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
            $label_y_offset += $self->subtitle_height - 16;                        
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

    my $features = $subtrack->{'features'};

    ## Single line? Build into singleton set.
    $features = [ $features ] if ref $features ne 'ARRAY';

    ## Draw them! 
    my $plot_conf = {
      line_score    => $line_score,
      line_px       => $line_px,
      pix_per_score => $pix_per_score,
      max_score     => $max_score,
      unit          => $subtrack->{'metadata'}{'unit'},
      graph_type    => $subtrack->{'metadata'}{'graphType'} || $track_config->get('graph_type'),
      same_strand   => $track_config->get('same_strand'),
      colour        => $subtrack->{'metadata'}{'color'} || $subtrack->{'metadata'}{'colour'},
      colours       => $subtrack->{'metadata'}{'gradient'},
      alt_colour    => $subtrack->{'metadata'}{'altColor'},
    };

    my $subtitle_colour = $plot_conf->{'colour'};
    my $subtitle_y      = $top + 8;
    my $subtitle = {
                    'text'    => $subtrack->{'metadata'}{'name'},
                    'colour'  => $self->make_readable($subtitle_colour),
                    'y'       => $top + 8,
                    };

    ## Shift the graph down a little if we're drawing an in-track label
    if ($subtrack->{'metadata'}{'name'}) {
      $plot_conf->{'y_offset'} = $subtitle_y + 12;
    }

    ## Determine absolute positioning
    $plot_conf->{'absolute_xy'} = {
                                    'absolutex' => 1,
                                    'absolutey' => 1,
                                  };

    $self->draw_wiggle($plot_conf, $features);
    $self->draw_subtitle($subtitle);
  }

  return @{$self->glyphs||[]};
}

########## DRAW INDIVIDUAL GLYPHS ###################

####### FEATURES ##################

sub draw_wiggle {
  my ($self, $c, $features) = @_;
  return unless $features && $features->[0];

  my $same_strand  = $c->{'same_strand'};
  my $slice_length = $self->{'container'}->length;
  $features = [ sort { $a->{'start'} <=> $b->{'start'} } @$features ];
  my ($previous_x,$previous_y);

  for (my $i = 0; $i < @$features; $i++) {
    my $f = $features->[$i];

    if (defined($f->{'strand'})) {
      if ($f->{'strand'} == 0) {
        ## Unstranded data goes on the reverse strand
        next if $same_strand && $same_strand == 1;
      }
      else {
      ## Skip unless feature is on this strand
      next if defined($same_strand) && $f->{'strand'} != $same_strand;
      }
    }

    my ($current_x,$current_score);
    $current_x     = ($f->{'end'} + $f->{'start'}) / 2;
    $current_score = $f->{'score'};
    my $current_y  = $c->{'line_px'}-($current_score-$c->{'line_score'}) * $c->{'pix_per_score'};
    next unless $current_x <= $slice_length;

    if(defined $previous_x) {
      push @{$self->glyphs}, $self->Line({
                                            x         => $current_x,
                                            y         => $current_y,
                                            width     => $previous_x - $current_x,
                                            height    => $previous_y - $current_y,
                                            colour    => $self->set_colour($c, $f),
                                            absolutey => 1,
                                          });
    }

    $previous_x = $current_x;
    $previous_y = $current_y;
  }
}

####### AXES AND LABELS ###########

sub draw_axes {
### Axes for the graph
  my ($self, $top, $zero, $bottom, $slice_length) = @_;

  ## horizontal line
  my $params = {
                x         => 0,
                y         => $zero,
                width     => $slice_length,
                height    => 0,
                absolutey => 1,
                colour    => $self->track_config->get('axis_colour') || 'red',
                dotted    => $self->track_config->get('graph_type') eq 'line' ? 0 : 1,
  };
  push @{$self->glyphs}, $self->Line($params);

  ## vertical line
  $params->{'y'}          = $top;
  $params->{'width'}      = 0;
  $params->{'height'}     = $bottom - $top;
  $params->{'absolutex'}  = 1;
  push @{$self->glyphs}, $self->Line($params);
}

sub set_colour {
### Make final decision on feature colour before drawing it
### @param c Hashref - track configuration
### @param f Hashref - feature
### @return String - colour of feature
  my ($self, $c, $f) = @_;
  my $cutoff = $c->{'alt_colour_cutoff'} || 0;
  my $colour = ($c->{'alt_colour'} && $f->{'score'} < $cutoff)
                  ? $c->{'alt_colour'} : $f->{'colour'};
  $colour ||= 'black';
  return $colour;
}

sub draw_score {
### Max and min scores on axes
  my ($self, $y, $value) = @_;

  my $text      = sprintf('%.2f',$value);
  my $text_info = $self->get_text_info($text);
  my $width     = $text_info->{'width'};
  my $height    = $text_info->{'height'};
  my $colour    = $self->track_config->get('axis_colour') || 'red';

  my %params = ( 
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    colour        => $colour,
  );

  ## Score label - make it slightly smaller than other labels
  push @{$self->glyphs}, $self->Text({
                                      text        => $text,
                                      height      => $height,
                                      width       => $width,
                                      x           => -2 - $width,
                                      y           => $y - $height * 0.75,
                                      textwidth   => $width * 0.9,
                                      halign      => 'right',
                                      font        => $self->{'font_name'}, 
                                      ptsize      => $self->{'font_size'} * 0.9,
                                      %params
                                    });

  ## 'Tick' on y-axis 
  push @{$self->glyphs}, $self->Rect({
                                      height        => 0,
                                      width         => 5,
                                      y             => $y,
                                      x             => -8,
                                      %params
                                    });
}

sub draw_guideline {
  my ($self, $width, $y, $type) = @_;

  $type ||= '1';
  push @{$self->glyphs}, $self->Line({
                                        x         => 0,
                                        y         => $y,
                                        width     => $width,
                                        height    => 1,
                                        colour    => 'grey90',
                                        absolutey => 1,
                                        dotted => $type,
                                      });
}

sub add_minilabel {}

1;
