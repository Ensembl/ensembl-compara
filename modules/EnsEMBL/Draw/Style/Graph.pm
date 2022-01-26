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
            ],
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
  my $track_config    = $self->track_config;

  my $graph_conf    = {};
  my $multi_wiggle  = $track_config->get('multi');
  if ($multi_wiggle) {
    # Merge metadata of subtracks
    my $metadata = $data->[0]{'metadata'};
    $metadata->{'max_score'} =
      max(map { $_->{'metadata'}{'max_score'} } @$data);
    $metadata->{'min_score'} =
      min(map { $_->{'metadata'}{'min_score'} } @$data);

    ## Draw any axes, track labels, etc
    $graph_conf = $self->draw_graph_base($metadata);
  }

  my $height   = $track_config->get('height');

  foreach my $subtrack (@$data) {
    my $metadata = $subtrack->{'metadata'} || {};
    my $features = $subtrack->{'features'};

    unless ($multi_wiggle) {
      ## Draw any axes, track labels, etc
      $graph_conf = $self->draw_graph_base($metadata);
    }

    ## Set cutoff point for top of graph if we have one
    if (defined($self->{'cutoff'})) {
      $graph_conf->{'cutoff_max'} = $self->{'cutoff'};
    }
    elsif (defined($metadata->{'y_max'})) {
      $graph_conf->{'cutoff_max'} = $metadata->{'y_max'}; 
    }

    if (defined($metadata->{'y_min'})) {
      $graph_conf->{'cutoff_min'} = $metadata->{'y_min'}; 
    }

    ## Single line? Build into singleton set.
    $features = [ $features ] if ref $features ne 'ARRAY';

    ## Work out a default colour
    my $colour = $track_config->get('colour')
                  || $subtrack->{'metadata'}{'colour'}
                  || $subtrack->{'metadata'}{'color'}; ## default

    ## Select a colour to indicate truncated values
    my $truncate_colour = ($colour eq 'black' || $colour eq '0,0,0') ? 'red' : 'black';

    ## Draw them! 
    my $plot_conf = {
      height          => $height,
      pix_per_score   => $track_config->get('pix_per_score'),
      default_strand  => $track_config->get('default_strand'),
      unit            => $subtrack->{'metadata'}{'unit'},
      graph_type      => $subtrack->{'metadata'}{'graphType'} || $track_config->get('graph_type'),
      colour          => $colour,
      truncate_colour => $truncate_colour,
      colours         => $subtrack->{'metadata'}{'gradient'},
      alt_colour      => $subtrack->{'metadata'}{'altColor'},
      %$graph_conf,
    };

    ## Determine absolute positioning for graph
    $plot_conf->{'absolute_xy'} = {'absolutey' => 1};
    ## Absolutex is weird and finicky - some graphs won't show if it's even defined
    if ($track_config->get('absolutex')) {
      $plot_conf->{'absolute_xy'}{'absolutex'} = 1;
    }

    $self->draw_wiggle($plot_conf, $features);
    $self->draw_hidden_bgd($height);
  }
  ## Only add height once, as we superimpose subtracks on a graph
  my $total_height = $track_config->get('total_height') || 0;
  $track_config->set('total_height', $total_height + $height);

  return @{$self->glyphs||[]};
}

########## DRAW INDIVIDUAL GLYPHS ###################

####### FEATURES ##################

sub draw_wiggle {
  my ($self, $c, $features) = @_;

  return unless $features && @$features;

  my $slice_length  = $self->image_config->container_width;
  if(ref($features->[0]) eq 'HASH') {
    $features = [ sort { $a->{'start'} <=> $b->{'start'} } @$features ];
  }
  my ($previous_x,$previous_y);
  my $plain_x = 0;

  for (my $i = 0; $i < @$features; $i++) {
    my $f = $features->[$i];
    unless(ref($f) eq 'HASH') {
      # Plain old value
      $f = {
        start => $plain_x,
        end => $plain_x+$c->{'unit'},
        score => $f,
      };
      $plain_x += $c->{'unit'};
    }
    my ($current_x,$current_score);
    $current_x     = ($f->{'end'} + $f->{'start'}) / 2;
    next unless $current_x <= $slice_length;

    $current_score = $f->{'score'};
    my ($colour, $ok_score);
    if ($current_score =~ /INF/) {
      $colour   = 'black';
      $ok_score = $current_score eq '-INF' ? $c->{'min_score'} : $c->{'max_score'};
    }
    elsif (defined($c->{'cutoff_min'}) && $c->{'cutoff_min'} ne '' && $current_score < $c->{'cutoff_min'}) {
      $ok_score = $c->{'cutoff_min'};
    }
    elsif (defined($c->{'cutoff_max'})  && $c->{'cutoff_max'} ne '' && $current_score > $c->{'cutoff_max'}) {
      $ok_score = $c->{'cutoff_max'};
    }
    else {
      $colour   = $self->set_colour($c, $f);
      $ok_score = $current_score;
    }
    my $current_y = $c->{'line_px'} - ($ok_score - $c->{'line_score'}) * $c->{'pix_per_score'};

    if(defined $previous_x) {
      push @{$self->glyphs}, $self->Line({
                                            x         => $current_x,
                                            y         => $current_y,
                                            width     => $previous_x - $current_x,
                                            height    => $previous_y - $current_y,
                                            colour    => $colour,
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
  $colour ||= $c->{'colour'};
  $colour ||= 'black';
  return $colour;
}

sub draw_score {
### Max and min scores on axes
  my ($self, $y, $value) = @_;

  my $text      = $self->track_config->get('integer_score') ? int($value) : sprintf('%.2f',$value);
  my $text_info = $self->get_text_info($text);
  my $width     = $text_info->{'width'};
  my $height    = $text_info->{'height'};
  my $colour    = 'black'; 

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
                                      x           => -8 - $width,
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
