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

package EnsEMBL::Draw::Role::Wiggle;

use strict;
use warnings;
no warnings 'uninitialized';

### Role for tracks that draw data as a continuous line 

use Role::Tiny;

sub render_compact {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph::Barcode']);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('no_axis', 1);
  $self->_render_aggregate;
}

sub render_signal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph::Bar']);
  $self->{'my_config'}->set('height', 60);
  $self->_render_aggregate;
}

sub render_feature_with_signal { 
  my $self = shift;
  my $graph_class = $self->_select_graph_type;
  $self->{'my_config'}->set('drawing_style', [$graph_class, 'Feature']);
  $self->_render; 
}

sub render_gradient {
### Features coloured on a gradient by score, e.g. pvalues
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph::Heatmap']);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('no_axis', 1);
  $self->{'my_config'}->set('use_pvalue', 1);
  $self->_render_aggregate;
}

sub render_tiling {
  ## For backwards compatibility - because 'tiling' is a meaningless name!
  my $self = shift;
  $self->render_signal;
}

sub _select_graph_type {
  my $self = shift;
  my $graph_class;
  if ($self->{'my_config'}->get('graph_type') && $self->{'my_config'}->get('graph_type') eq 'line') {
    $graph_class = 'Graph';
  }
  else {
    $graph_class = 'Graph::Histogram';
  }
  return $graph_class;
}

sub _render_aggregate {
  my $self = shift;

  ## Check to see if we draw anything because of size!
  my $max_length  = $self->my_config('threshold')   || 10000;
  my $wiggle_name = $self->my_config('wiggle_name') || $self->my_config('label');

  if ($self->{'container'}->length > $max_length * 1010) {
    my $height = $self->errorTrack("$wiggle_name only displayed for less than $max_length Kb");
    $self->_offset($height + 4);
    return 1;
  }

  my $maxHeightPixels = $self->{'my_config'}->get('maxHeightPixels') || '';
  (my $default_height = $maxHeightPixels) =~ s/^.*:([0-9]*):.*$/$1/;
  if ($default_height) {  
    $self->{'my_config'}->set('height', $default_height);
  }
  else {
   $self->{'my_config'}->set('height', 60) unless $self->{'my_config'}->get('height');
  }

  $self->{'my_config'}->set('bumped', 0);
  $self->{'my_config'}->set('axis_colour', $self->my_colour('axis')) 
    unless $self->{'my_config'}->get('axis_colour');

  ## Now we try and draw the features
  my $error = $self->draw_aggregate($self->{'data'});
  return unless $error && $self->{'config'}->get_option('opt_empty_tracks') == 1;

  my $here = $self->my_config('strand') eq 'b' ? 'on this strand' : 'in this region';

  my $height = $self->errorTrack("No $error $here", 0, $self->{'my_config'}->{'initial_offset'});

  return 1;
}

sub _render {
  my $self = shift;

  ## Check to see if we draw anything because of size!
  my $max_length  = $self->my_config('threshold')   || 10000;
  my $wiggle_name = $self->my_config('wiggle_name') || $self->my_config('label');

  if ($self->{'container'}->length > $max_length * 1010) {
    my $height = $self->errorTrack("$wiggle_name only displayed for less than $max_length Kb");
    $self->_offset($height + 4);
    return 1;
  }

  (my $default_height = $self->{'my_config'}->get('maxHeightPixels')) =~ s/^.*:([0-9]*):.*$/$1/;
  if ($default_height) {  
    $self->{'my_config'}->set('height', $default_height);
  }
  else {
   $self->{'my_config'}->set('height', 60) unless $self->{'my_config'}->get('height');
  }

  $self->{'my_config'}->set('absolutex', 1);
  $self->{'my_config'}->set('bumped', 0);
  $self->{'my_config'}->set('axis_colour', $self->my_colour('axis'));

  my $tracks = $self->{'data'};
  return unless ref $tracks eq 'ARRAY';

  # Make sure subtitles will be correctly coloured
  unless ($self->{'my_config'}->get('subtitle_colour')) {
    my $sub_colour = $self->{'my_config'}->get('score_colour') 
                      || $self->my_colour('score') || 'blue';
    $self->{'my_config'}->set('subtitle_colour', $sub_colour);
  }

  foreach (@$tracks) {
    next unless scalar(@{$_->{'features'}||[]});
    ## Work out maximum and minimum scores
    my $track_min = $self->{'my_config'}->get('min_score');
    my $track_max = $self->{'my_config'}->get('max_score');
    my ($min_score, $max_score) = $self->_get_min_max($_);
    $_->{'metadata'}{'min_score'} = $min_score;
    $_->{'metadata'}{'max_score'} = $max_score;
    $self->{'my_config'}->set('min_score', $min_score) 
      if !$track_min || $min_score < $track_min;
    $self->{'my_config'}->set('max_score', $max_score) 
      if !$track_max || $max_score > $track_max;
  }

  ## Now we try and draw the features
  my $error = $self->draw_features($tracks);
  return unless $error && $self->{'config'}->get_option('opt_empty_tracks') == 1;

  my $here = $self->my_config('strand') eq 'b' ? 'on this strand' : 'in this region';

  my $height = $self->errorTrack("No $error $here", 0, $self->{'my_config'}->{'initial_offset'});

  return 1;
}

sub _get_min_max {
### Get minimum and maximum scores for a set of features
  my ($self, $dataset) = @_;
  my $features = $dataset->{'features'} || [];
  return unless scalar @$features;
  my $metadata = $dataset->{'metadata'} || {};
  my ($min, $max) = (0, 0);

  if ($metadata->{'viewLimits'}) {
    ($min, $max) = split ':', $metadata->{'viewLimits'};
  }
  else {
    foreach (@$features) {
      my $score = ref $_ eq 'HASH' ? $_->{'score'} : $_;
      next unless $score;
      $min = $score if !$min || $score < $min;
      $max = $score if !$max || $score > $max;
    }
  }
  return ($min, $max);
}

1;
