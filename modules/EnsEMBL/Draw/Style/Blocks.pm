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

package EnsEMBL::Draw::Style::Blocks;

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

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
### Create all the glyphs required by this style
### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data          = $self->data;
  my $image_config  = $self->image_config;
  my $track_config  = $self->track_config;
 
  foreach my $block (@$data) {
    my $show_label = $track_config->get('show_labels') && $block->{'label'};
    my $text_info = $self->get_text_info($block->{'label'});
    my $feature_row = 0;
    my $label_row   = 0;
    my $new_y;

    ## Work out if we're bumping the whole feature or just the label
    my $bumped     = $track_config->get('bumped');
    if ($bumped) {
      my $bump = $self->set_bump_row($block->{'start'}, $block->{'end'}, $show_label, $text_info);
      $label_row   = $bump;
      $feature_row = $bump unless $bumped eq 'labels_only';       
    }
    next if $feature_row < 0; ## Bumping code returns -1 if there's a problem 

    ## Work out where to place the feature
    my $block_height  = $track_config->get('height') || $text_info->{'height'};
    my $label_height  = $show_label ? $text_info->{'height'} : 0;

    my $block_width   = $block->{'end'} - $block->{'start'} + 1;
    my $slice_width   = $image_config->container_width;
    $block_width      = $slice_width - $block->{'start'} if ($block_width > $slice_width);

    my $labels_height = $label_row * $label_height;
    my $add_labels    = !$bumped || $bumped eq 'labels_only' ? 0 : $labels_height;

    my $position  = {
                    'y'       => (($feature_row + 1) * ($block_height + 4)) + $add_labels,
                    'width'   => $block_width,
                    'height'  => $block_height,
                    };
    
    $self->draw_block($block, $position);

    ## Optional label
    if ($show_label) {
      if ($track_config->get('label_overlay')) {
        $new_y = $position->{'y'};
      }
      else {
        $new_y = $position->{'y'} + $block_height;
        $new_y += $labels_height if ($bumped eq 'labels_only');
      }
      $position = {
                    'y'       => $new_y,
                    'width'   => $text_info->{'width'}, 
                    'height'  => $text_info->{'height'},
                  };
      $self->add_label($block, $position);
    }
  }

  return @{$self->glyphs||[]};
}

sub draw_block {
### Create a glyph that's a simple filled rectangle
### @param block Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $block, $position) = @_;

  return unless ($block->{'colour'} || $block->{'bordercolour'});

  ## Set parameters
  my $params = {
                  x            => $block->{'start'},
                  y            => $position->{'y'},
                  width        => $position->{'width'},
                  height       => $position->{'height'},
                  href         => $block->{'href'},
                  title        => $block->{'title'},
                  absolutey    => 1,
                };

  $params->{'colour'} = $block->{'colour'} if $block->{'colour'};
  $params->{'bordercolour'} = $block->{'bordercolour'} if $block->{'bordercolour'};

  push @{$self->glyphs}, $self->Rect($params);
}

sub add_label {
### Create a text label
### @param block Hashref - data for a single feature
### @param position Hashref - information about the label's size and position
  my ($self, $block, $position) = @_;

  my $label = {
                font      => $self->{'font_name'},
                colour    => $block->{'label_colour'} || 'black',
                height    => $self->{'font_size'},
                ptsize    => $self->{'font_size'},
                text      => $block->{'label'},
                x         => $block->{'start'},
                y         => $position->{'y'},
                width     => $position->{'width'},
                height    => $position->{'height'},
                href      => $block->{'href'},
                title     => $block->{'title'},
                absolutey => 1,
              };

  push @{$self->glyphs}, $self->Text($label);
}

1;
