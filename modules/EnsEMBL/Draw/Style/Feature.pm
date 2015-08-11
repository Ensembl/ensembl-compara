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

package EnsEMBL::Draw::Style::Feature;

=pod
Renders a track as a series of simple rectangular blocks

Also a parent module to most styles that render individual features
rather than graphs or other aggregate data.

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
  my $bumped          = $track_config->get('bumped');
  my $vspacing        = defined($track_config->get('vspacing')) ? $track_config->get('vspacing') : 4;
  my $same_strand     = $track_config->get('same_strand');
  ## In case the file contains multiple tracks, start each subtrack below the previous one
  my $y_start         = $track_config->get('y_start') || 0;
  my $show_label      = 0;
  my $label_height    = 0;
  my $total_height    = 0;

  foreach my $feature (@$data) {

    next if defined($same_strand) && $feature->{'strand'} != $same_strand;

    $show_label     = $track_config->get('show_labels') && $feature->{'label'} ? 1 : 0;
    my $text_info   = $self->get_text_info($feature->{'label'});
    my $feature_row = 0;
    my $label_row   = 0;
    my $new_y;

    ## Set default colour if there is one
    $feature->{'colour'} ||= $default_colour;

    ## Work out if we're bumping the whole feature or just the label
    if ($bumped) {
      my $bump = $self->set_bump_row($feature->{'start'}, $feature->{'end'}, $show_label, $text_info);
      $label_row   = $bump;
      $feature_row = $bump unless $bumped eq 'labels_only';       
    }
    next if $feature_row < 0; ## Bumping code returns -1 if there's a problem 

    ## Work out where to place the feature
    my $feature_height  = $track_config->get('height') || $text_info->{'height'};
    $label_height    = $show_label ? $text_info->{'height'} : 0;

    my $feature_width   = $feature->{'end'} - $feature->{'start'};

    if ($feature_width == 0) {
      ## Fix for single base-pair features
      $feature_width = 1;
    }
    else {
      ## Truncate to viewport - but don't alter feature hash because we may need it
      my ($drawn_start, $drawn_end) = $feature->{'end'} - $feature->{'start'}
                                        ? ($feature->{'start'}, $feature->{'end'})
                                        : ($feature->{'end'}, $feature->{'start'});
      $drawn_start        = 0 if $drawn_start < 0;
      $drawn_end          = $slice_width if $drawn_end > $slice_width;
      $feature_width      = $drawn_end - $drawn_start; 
    }

    my $labels_height   = $label_row * $label_height;
    my $add_labels      = (!$bumped || $bumped eq 'labels_only') ? 0 : $labels_height;
    my $y               = ($y_start + ($feature_row + 1) * ($feature_height + $vspacing)) + $add_labels;
    my $position  = {
                    'y'           => $y,
                    'width'       => $feature_width,
                    'height'      => $feature_height,
                    'image_width' => $slice_width,
                    };

    $self->draw_feature($feature, $position);
    $total_height = $y if $y > $total_height;
  
    ## Optional label
    if ($show_label) {
      if ($track_config->get('label_overlay')) {
        $new_y = $position->{'y'};
      }
      else {
        $new_y = $position->{'y'} + $feature_height;
        $new_y += $labels_height if ($bumped eq 'labels_only');
      }
      $position = {
                    'y'       => $new_y,
                    'width'   => $text_info->{'width'}, 
                    'height'  => $text_info->{'height'},
                    'image_width' => $slice_width,
                  };
      $self->add_label($feature, $position);
      $total_height = $new_y if $new_y > $total_height;
    }
  }
  ## Add label height if last feature had a label
  $total_height += $label_height if $show_label;
  $track_config->set('y_start', $y_start + $total_height);
  return @{$self->glyphs||[]};
}

sub draw_feature {
### Create a glyph that's a simple filled rectangle
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  return unless ($feature->{'colour'} || $feature->{'bordercolour'});

  ## Set parameters
  my $x = $feature->{'start'};
  $x    = 0 if $x < 0;
  my $params = {
                  x            => $x,
                  y            => $position->{'y'},
                  width        => $position->{'width'},
                  height       => $position->{'height'},
                  href         => $feature->{'href'},
                  title        => $feature->{'title'},
                  absolutey    => 1,
                };
  $params->{'colour'}       = $feature->{'colour'} if $feature->{'colour'};
  $params->{'bordercolour'} = $feature->{'bordercolour'} if $feature->{'bordercolour'};

  push @{$self->glyphs}, $self->Rect($params);
}

sub add_label {
### Create a text label
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the label's size and position
  my ($self, $feature, $position) = @_;
  ## TODO - darken label colour if it's too pale - see "projector" image export
  my $colour = $feature->{'label_colour'} || $feature->{'colour'} || 'black';

  ## Stop labels from overlapping edge of image
  my $x = $feature->{'start'};
  $x = 0 if $x < 0;
  my $image_width_in_pixels = $position->{'image_width'} * $self->{'pix_per_bp'};
  my $x_in_pixels           = $x * $self->{'pix_per_bp'}; 
  if (($x_in_pixels + $position->{'width'}) > $image_width_in_pixels) {
    $x = $position->{'image_width'} - ($position->{'width'} / $self->{'pix_per_bp'});
  }

  my $label = {
                font      => $self->{'font_name'},
                colour    => $colour,
                height    => $self->{'font_size'},
                ptsize    => $self->{'font_size'},
                text      => $feature->{'label'},
                x         => $x,
                y         => $position->{'y'},
                width     => $position->{'width'},
                height    => $position->{'height'},
                href      => $feature->{'href'},
                title     => $feature->{'title'},
                absolutey => 1,
              };

  push @{$self->glyphs}, $self->Text($label);
}

1;
