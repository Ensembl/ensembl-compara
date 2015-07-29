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

package EnsEMBL::Draw::Style::Feature::Interaction;

### Renders a track as a series of features with internal structure
### Blocks may be joined with horizontal lines, semi-transparent
### blocks or no joins at all 

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

  foreach my $feature (@$data) {

    ## Set default colour if there is one
    my $colour      = $feature->{'colour'} || $default_colour;

    my %defaults = (
                    'y'           => 0,
                    'height'      => $feature_height,
                    'colour'      => $colour,
                    'absolute_y'  => 1,
                    );

    $self->draw_feature($feature, %defaults);

  }
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
  my $image_width   = $self->image_config->container_width; 
  my $feature_start = $feature->{'start'};
  my $current_x     = $feature_start;
  $current_x        = 0 if $current_x < 0;

  my ($block_1, $block_2) = @{$structure};

  ## Draw first block
  unless ($block_1->{'end'} < 0) { 
    my %params        = %defaults;
    $params{'x'}      = $block_1->{'start'};
    $params{'width'}  = $block_1->{'end'} - $block_1->{'start'};
    $self->draw_block(%params);
  }

=pod
  ## Draw arc

  ## Default behaviour is to draw arc from middles of features
  ## Of course for the arcs we have to use the real coordinates, 
  ## not the ones constrained to the viewport
  my $arc_start       = $s1 == $e1 ? $s1 - 0.5
                                : $s1 + ceil(($e1 - $s1) / 2);
  my $arc_end         = $s2 == $e2 ? $s2 - 0.5
                                : $s2 + floor(($e2 - $s2) / 2);

  my $direction_1     = $f->direction_1;
  my $direction_2     = $f->direction_2;
  if ($direction_1 || $direction_2) {
    if ($direction_1 =~ /\+/) {
       $arc_start  = $s1 == $e1 ? $s1 - 1 : $s1;
       $arc_end    = $s2 == $e2 ? $s2 - 1 : $s2;
    }
    else {
      $arc_start = $e1;
      $arc_end   = $e2;
    }
  }
  ## Don't show arcs if both ends lie outside viewport
  next if ($arc_start < 0 && $arc_end > $length);
=cut

  ## Draw second block
  unless ($block_2->{'start'} > $image_width) {
    my %params        = %defaults;
    $params{'x'}      = $block_2->{'start'};
    $params{'width'}  = $block_2->{'end'} - $block_2->{'start'};
    $self->draw_block(%params);
  }
}

sub draw_block {
  my ($self, %params) = @_;
  push @{$self->glyphs}, $self->Rect(\%params);
}

sub draw_join {
  my ($self, %params) = @_;
  push @{$self->glyphs}, $self->Arc(\%params);
}

1;
