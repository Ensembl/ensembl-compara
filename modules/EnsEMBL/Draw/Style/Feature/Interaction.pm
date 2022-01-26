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

package EnsEMBL::Draw::Style::Feature::Interaction;

### Renders a track as a series of features with internal structure
### Blocks may be joined with horizontal lines, semi-transparent
### blocks or no joins at all 

use strict;

use List::Util qw(min max);
use POSIX qw(floor ceil);

use parent qw(EnsEMBL::Draw::Style::Feature);


sub create_glyphs {
### A much-simplified version of the parent method, but necessary
### because arc-rendering is very different from normal tracks
  my $self = shift;

  my $data            = $self->data;
  my $image_config    = $self->image_config;
  my $track_config    = $self->track_config;
  ## Set some track-wide variables
  my $default_colour  = $track_config->get('default_colour');
  my $feature_height  = $track_config->get('height');
  my $slice_width     = $image_config->container_width;
  my $max_arc         = 0;
  my $current_max     = 0;

  foreach my $subtrack (@$data) {
    foreach my $feature (@{$subtrack->{'features'}||[]}) {

      ## Set default colour if there is one
      my $colour      = $feature->{'colour'} || $default_colour;

      my %defaults = (
                      'y'           => 0,
                      'height'      => $feature_height,
                      'colour'      => $colour,
                      'href'        => $feature->{'href'},
                      'absolute_y'  => 1,
                      );

      $current_max = $self->draw_feature($feature, %defaults);
      $max_arc = $current_max if $current_max > $max_arc;
    }
  }

  ## Limit track height to that of biggest arc plus some padding
  my $max_height = $max_arc/2 + 10;
  $track_config->set('max_height', $max_height);
  $self->draw_hidden_bgd($max_height);

  return @{$self->glyphs||[]};
}

sub draw_feature {
### Create each "feature" as a set of glyphs: blocks plus joins
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, %defaults) = @_;

  my $structure = $feature->{'structure'};
  return unless $structure;

  ## Basic parameters for all parts of the feature
  my $image_width         = $self->image_config->container_width; 
  my $feature_start = $feature->{'start'};
  my $current_x     = $feature_start;
  $current_x        = 0 if $current_x < 0;

  my ($block_1, $block_2) = @{$structure};

  ## Flip blocks if necessary
  ## First the coordinates within each block
  foreach ($block_1, $block_2) {
    if ($_->{'start'} > $_->{'end'}) {
      ($_->{'start'}, $_->{'end'}) = ($_->{'end'}, $_->{'start'});
    }
  }
  ## Then the blocks relative to one another
  ($block_1, $block_2) = ($block_2, $block_1) if $block_2->{'end'} < $block_1->{'start'};

  ## Draw first block
  unless ($block_1->{'end'} < 0) { 
    my %params        = %defaults;
    ## Constrain blocks to viewport
    my $block_start   = max($block_1->{'start'}, 0);
    my $block_end     = min($block_1->{'end'}, $image_width);
    $params{'x'}      = $block_start;
    $params{'width'}  = $block_end - $block_start + 1;
    $self->draw_block(%params);
  }

  ## Draw arc
  my %params  = %defaults;
  my $max_arc = $self->draw_join($feature, %params);

  ## Draw second block
  unless ($block_2->{'start'} > $image_width) {
    my %params        = %defaults;
    ## Constrain blocks to viewport
    my $block_start   = max($block_2->{'start'}, 0);
    my $block_end     = min($block_2->{'end'}, $image_width);
    $params{'x'}      = $block_start;
    $params{'width'}  = $block_end - $block_start + 1;
    $self->draw_block(%params);
  }
  return $max_arc;
}

sub draw_block {
  my ($self, %params) = @_;
  push @{$self->glyphs}, $self->Rect(\%params);
}

sub draw_join {
  my ($self, $feature, %params) = @_;

  my $s1 = $feature->{'structure'}[0]{'start'};
  my $e1 = $feature->{'structure'}[0]{'end'};
  my $s2 = $feature->{'structure'}[1]{'start'};
  my $e2 = $feature->{'structure'}[1]{'end'};

  my $image_width = $self->image_config->container_width;
  my $length      = $self->track_config->get('slice_length');
  my $pix_per_bp  = $self->image_config->transform_object->scalex;

  my ($arc_start, $arc_end);
  my $direction       = $feature->{'direction'};
  ## Default behaviour is to draw arc from middles of features
  ## Of course for the arcs we have to use the real coordinates, 
  ## not the ones constrained to the viewport
  if ($direction) {
    if ($direction =~ /\+/) {
      $arc_start  = $s1;
      $arc_end    = $s2;
    }
    else {
      $arc_start = $e1;
      $arc_end   = $e2;
    }
  }
  else {
    $arc_start  = $s1 == $e1 ? $s1 - 0.5
                             : $s1 + ceil(($e1 - $s1) / 2);
    $arc_end    = $s2 == $e2 ? $s2 - 0.5
                             : $s2 + floor(($e2 - $s2) / 2);
  }


  ## Flip start and end if necessary
  ($arc_start, $arc_end) = ($arc_end, $arc_start) if ($arc_start > $arc_end);

  ## Don't show arcs if both ends lie outside viewport
  next if ( ($arc_start < 0 && $arc_end <= 0)
                  || ($arc_start >= $length && $arc_end > $length)
                  || ($arc_start < 0 && $arc_end > $length)
           );

  ## Somewhat confusingly, the drawing code uses coordinates for horizontal dimensions
  ## but pixels for vertical ones, which makes the following maths hideous!
  ## Convert horizontal dimensions to pixels to make things sane:
  my $pixel_start = ceil($arc_start * $pix_per_bp);
  my $pixel_end   = ceil($arc_end * $pix_per_bp);

  ## Set some sensible limits
  my $width     = $image_width;
  my $max_width = $width * 2;
  my $max_depth = 250; ## should be less than image width! 


  ## Start with a basic circular arc, then constrain to above limits
  my $start_point   = 0; ## righthand end of arc
  my $end_point     = 180; ### lefthand end of arc
  my $major_axis    = $pixel_end - $pixel_start;
  my $minor_axis    = $major_axis;
  $major_axis       = $max_width if $major_axis > $max_width;
  $minor_axis       = $max_depth if $minor_axis > $max_depth;
  my $a             = $major_axis / 2;
  my $b             = $minor_axis / 2;

  ## Measurements needed for drawing partial arcs
  my $centre        = $pixel_start + $a;
  my $left_height   = $minor_axis; ## height of curve at left of image
  my $right_height  = $minor_axis; ## height of curve at right of image

  ## Cut curve off at edge of track if ends lie outside the current window
  ## Note that we have to calculate the angle theta as if we were drawing a
  ## circle, as there's something funky going on in GD!
  if ($pixel_start < 0) {
    my $x = abs($centre);
    $x = $a if $x > $a;
    $left_height = $self->ellipse_y($x, $a, $b);
    my $theta = $self->truncate_ellipse($x, $a, $a);
    if ($centre > 0) {
      $end_point -= $theta;
    }
    else {
      $end_point = $theta;
    }
  }

  if ($s2 >= $length) {
    my ($x, $theta);
    $x = abs($width - $centre);
    $x = $a if $x > $a;
    $right_height = $self->ellipse_y($x, $a, $b);
    my $theta = $self->truncate_ellipse($x, $a, $a);
    if ($centre > $width) {
      $start_point = 180 - $theta;
    }
    else {
      $start_point = $theta;
    }
  }

  ## Are one or both ends of this interaction visible?
  my $end = {};
  $end->{'left'} = 1 if $e1 > 0;
  $end->{'right'} = 1 if $s2 < $length;

  ## Keep track of the maximum visible arc height, to save us a lot of grief
  ## trying to get rid of white space below the arcs
  ## Only use arc cutoff if there's a feature at one end of it 
  ## (and if the arc is less than 90 degrees, hence less than full height)
  ## otherwise we end up with no track height at all!
  my $max_arc;
  if (keys %$end < 2 && ($end_point - $start_point < 90)) {
    $max_arc = $left_height if (!$end->{'left'} && $left_height > $max_arc);
    $max_arc = $right_height if (!$end->{'right'} && $right_height > $max_arc);
  }
  else {
    $max_arc = $minor_axis if $minor_axis > $max_arc;
  }
  my $pixel_width = $pixel_end - $pixel_start;

  ## Finally, we have the coordinates to draw 
  my $arc_params = {
                    x             => $arc_end,
                    y             => $b + $params{'height'},
                    width         => $pixel_width,
                    absolutewidth => 1,
                    height        => $minor_axis,
                    start_point   => $start_point,
                    end_point     => $end_point,
                    colour        => $params{'colour'},
                    filled        => 0,
                    thickness     => 2,
                  };
  push @{$self->glyphs}, $self->Arc($arc_params);
  return $max_arc;
}

1;
