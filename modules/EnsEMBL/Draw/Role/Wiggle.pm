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

package EnsEMBL::Draw::Role::Wiggle;

### Role for tracks that draw data as a continuous line 

use Role::Tiny;

### Renderers

sub render_compact { 
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature']);
  $self->_render;
}

sub render_tiling { 
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph']);
  $self->_render; 
}

sub render_tiling_feature { 
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph', 'Feature']);
  $self->_render; 
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

  $self->{'my_config'}->set('height', 60);
  $self->{'my_config'}->set('bumped', 0);
  $self->{'my_config'}->set('axis_colour', $self->my_colour('axis'));

  my $tracks = $self->{'features'};

  ## Work out maximum and minimum scores
  my ($min_score, $max_score) = $self->_get_min_max($tracks);
  $self->{'my_config'}->set('min_score', $min_score);
  $self->{'my_config'}->set('max_score', $max_score);

  # Make sure subtitles will be correctly coloured
  unless ($self->{'my_config'}->get('subtitle_colour')) {
    my $sub_colour = $self->{'my_config'}->get('score_colour') || $self->my_colour('score') || 'blue';
    $self->{'my_config'}->set('subtitle_colour', $sub_colour);
  }

  ## Now we try and draw the features
  my $error = $self->draw_features;

=pod
  return unless $error && $self->{'config'}->get_option('opt_empty_tracks') == 1;

  my $here = $self->my_config('strand') eq 'b' ? 'on this strand' : 'in this region';

  my $height = $self->errorTrack("No $error $here", 0, $self->_offset);
  $self->_offset($height + 4);

  return 1;
=cut
}

sub _get_min_max {
### Get minimum and maximum scores for a set of features
  my ($self, $features) = @_;
  my ($min, $max);

  foreach my $f (@{$features||[]}) {
    if (ref($f) eq 'HASH') {
      if ($f->{'metadata'} && $f->{'metadata'}{'viewLimits'}) {
        return split ':', $f->{'metadata'}{'viewLimits'};
      }
      elsif ($f->{'features'}) {
        foreach (@{$f->{'features'}}) {
          next unless $_->{'score'};
          $min = $_->{'score'} if !$min || $_->{'score'} < $min;
          $max = $_->{'score'} if !$max || $_->{'score'} > $min;
        }
      }
    }
    else {
      next unless $f->{'score'};
      $min = $f->{'score'} if !$min || $f->{'score'} < $min;
      $max = $f->{'score'} if !$max || $f->{'score'} > $min;
    }
  }
 
  return ($min, $max);
}

1;
