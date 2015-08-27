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
            [
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
            ],
          ];

Note that in order to support multi-wiggle tracks, the data should be passed as an a array of arrays

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
  my $feature_colours = $track_config->get('feature_colours');
  my $default_colour  = $track_config->get('default_colour');
  my $slice_width     = $image_config->container_width;
  my $row_height      = $track_config->get('height') || 60;

  # max_score: score at top of y-axis on graph
  # min_score: score at bottom of y-axis on graph
  # range: scores spanned by graph (small value used if identically zero)
  # pix_per_score: vertical pixels per unit score
  my $max_score     = $track_config->get('max_score');
  my $min_score     = $track_config->get('min_score');
  my $range = $max_score-$min_score;
  if($range < 0.01) {
    # Oh dear, data all has pretty much same value ...
    if($max_score > 0.01) {
      # ... but it's not zero, so just move minimum down
      $min_score = 0;
    } else {
      # ... just create some sky
      $max_score = 0.1;
    }
  }
  $range = $max_score - $min_score;
  my $pix_per_score = $row_height/$range;

  # top: top of graph in pixel units, offset from track top (usu. 0)
  # line_score: value to draw "to" up/down, in score units (usu. 0)
  # line_px: value to draw "to" up/down, in pixel units (usu. 0)
  # bottom: bottom of graph in pixel units (usu. approx. pixel height)
  my $top = ($track_config->get('initial_offset')||0);
  my $line_score = max(0,$min_score);
  my $bottom = $top + $pix_per_score * $range;
  my $line_px = $bottom - ($line_score-$min_score) * $pix_per_score;

  # Shift down the lhs label to between the axes unless the subtitle is within the track
  if ($bottom - $top > 30 && $track_config->get('wiggle_subtitle')) {
    # luxurious space for centred label
    # graph is offset down if subtitled
    $self->{'label_y_offset'} =
        ($bottom - $top) / 2        # half-way-between
        + $track_config->get('subtitle_height')
        - 16;                       # two-line label so centre its centre
  } else {
    # tight, just squeeze it down a little
    $self->{'label_y_offset'} = 0;
  }

  # Extra left-legend stuff
  if ($track_config->get('labels')) {
    $self->add_minilabel($top);
  }

  # Draw axes and their numerical labels
  if (!$track_config->get('no_axis')) {
    $self->draw_axes($top, $line_px, $bottom, $slice_width);
  }

  if ($track_config->get('axis_label') ne 'off') {
    $self->draw_score($top, $max_score);
    $self->draw_score($bottom, $min_score);
  }

  if(!$track_config->get('no_axis') and !$track_config->get('no_guidelines')) {
    foreach my $i (1..4) {
      my $type;
      $type = 'small' unless $i % 2;
      $self->draw_guideline($slice_width, ($top*$i+$bottom*(4-$i))/4, $type);
    }
  }

  ## Single line? Build into singleton set.
  $data = [ $data ] if ref $data->[0] ne 'ARRAY';

  ## Draw them! 
  my $plot_conf = {
    line_score    => $line_score,
    line_px       => $line_px,
    pix_per_score => $pix_per_score,
    colour        => $track_config->get('score_colour') || 'blue',
    };

  foreach my $feature_set (@$data) {
    $plot_conf->{'colour'} = shift(@$feature_colours) if $feature_colours and @$feature_colours;
  
    if ($track_config->get('unit')) {
      $self->_draw_wiggle_points_as_graph($plot_conf, $feature_set);
    } 
    elsif ($self->track_config->get('graph_type') eq 'line') {
      $self->_draw_wiggle_points_as_line($plot_conf, $feature_set);
    } 
    else {
      $self->_draw_wiggle_points_as_bar_or_points($plot_conf, $feature_set);
    }
  }

  return @{$self->glyphs||[]};
}

########## DRAW INDIVIDUAL GLYPHS ###################

####### FEATURES ##################

sub _draw_wiggle_points_as_graph {
  my ($self, $c, $features) = @_;

  my $height = $c->{'pix_per_score'} * $self->track_config->get('max_score');

  push @{$self->glyphs}, $self->Barcode({
    values    => $features,
    x         => 1,
    y         => 0,
    height    => $height,
    unit      => $self->track_config->get('unit'),
    max       => $self->track_config->get('max_score'),
    colours   => [$c->{'colour'}],
    wiggle    => $self->track_config->get('graph_type'),
  });
}

sub _draw_wiggle_points_as_line {
  my ($self, $c, $features) = @_;
  return unless $features && $features->[0];

  my $slice_length = $self->{'container'}->length;
  $features = [ sort { $a->{'start'} <=> $b->{'start'} } @$features ];
  my ($previous_x,$previous_y);

  for (my $i = 0; $i < @$features; $i++) {
    my $f = $features->[$i];

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
                                            colour    => $f->{'colour'},
                                            absolutey => 1,
                                          });
    }

    $previous_x     = $current_x;
    $previous_y     = $current_y;
  }
}

sub _draw_wiggle_points_as_bar_or_points {
  my ($self, $c, $features) = @_;

  my $use_points    = $self->track_config->get('graph_type') eq 'points';
  my $max_score     = $self->track_config->get('max_score');

  foreach my $f (@$features) {
    my $start   = $f->{'start'};
    my $end     = $f->{'end'};
    my $score   = $f->{'score'};
    my $href    = $f->{'href'};
    my $height  = ($score - $c->{'line_score'}) * $c->{'pix_per_score'};
    my $title   = sprintf('%.2f',$score);

    push @{$self->glyphs}, $self->Rect({
                              y         => $c->{'line_px'} - max($height, 0),
                              height    => $use_points ? 0 : abs $height,
                              x         => $start - 1,
                              width     => $end - $start + 1,
                              absolutey => 1,
                              colour    => $f->{'colour'},
                              alpha     => $self->track_config->get('use_alpha') ? 0.5 : 0,
                              title     => $self->track_config->get('no_titles') ? undef : $title,
                              href      => $href,
                            });
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
