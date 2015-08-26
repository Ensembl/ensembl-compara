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
          ];
=cut

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
### Create all the glyphs required by this style
### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data            = $self->data;
  my $image_config    = $self->image_config;
  my $track_config    = $self->track_config;

  ## Set some track-wide variables
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

  # Make sure subtitles will be correctly coloured
  unless ($track_config->get('subtitle_colour')) {
    my $sub_colour = $track_config->get('score_colour') || $self->my_colour('score') || 'blue';
    $track_config->set('subtitle_colour', $sub_colour);
  }

  # Shift down the lhs label to between the axes unless the subtitle is within the track
  if($bottom-$top > 30 && $self->wiggle_subtitle) {
    # luxurious space for centred label
    # graph is offset down if subtitled
    $self->{'label_y_offset'} =
        ($bottom-$top)/2             # half-way-between
        + $self->subtitle_height
        - 16;                        # two-line label so centre its centre
  } else {
    # tight, just squeeze it down a little
    $self->{'label_y_offset'} = 0;
  }

  # Extra left-legend stuff
  if ($track_config->get('labels')) {
    $self->_add_minilabel($top);
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

  return @{$self->glyphs||[]};

}

########## DRAW INDIVIDUAL GLYPHS

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
                colour    => $self->track_config->get('axis_colour') || $self->my_colour('axis') || 'red',
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

  my $text = sprintf('%.2f',$value);
  my %font = $self->get_font_details('innertext', 1);
  my $width = [ $self->get_text_width(0, $text, '', %font) ]->[2];
  my $height = [ $self->get_text_width(0, 1, '', %font) ]->[3];
  my $colour = $self->track_config->('axis_colour') || $self->my_colour('axis')  || 'red';

  my %params = ( 
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    colour        => $colour,
  );

  push @{$self->glyphs}, $self->Text({
                                      text          => $text,
                                      height        => $height,
                                      width         => $width,
                                      x             => -10 - $width,
                                      y             => $y - $height/2,
                                      textwidth     => $width,
                                      halign        => 'right',
                                      %font,
                                      %params
                                    });

  push @{$self->glyphs}, $self->Rect({
                                      height        => 0,
                                      width         => 5,
                                      y             => $y,
                                      x             => -8,
                                      %params
                                    });
}



1;
