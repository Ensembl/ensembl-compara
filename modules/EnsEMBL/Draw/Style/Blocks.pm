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
Renders a track as a series of simple unconnected blocks
on one line (i.e. not stacked or bumped). Often referred to 
in the interface as "compact".

Also a parent module to most styles that render individual features
rather than graphs or other aggregate data.

This module expects data in the following format:

  $data = [
            {
              'start'         => 123456,
              'end'           => 123789,
              'colour'        => 'red',
              'label'         => 'Feature 1',                       # optional
              'label_colour'  => 'red',                             # optional
              'href'          => '/Location/View?r=123456-124789',  # optional  
              'title'         => 'Some text goes here',             # optional  
            },
            {
              'start'         => 123654,
              'end'           => 123987,
              'colour'        => 'blue',
              'label'         => 'Feature 2',                       # optional
              'label_colour'  => 'blue',                            # optional
              'href'         => '/Location/View?r=123654-124987',   # optional  
              'title'         => 'Some other text goes here',       # optional  
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
    my $text_info = $self->get_text_info($block->{'label'});
    my $row = 0;
    my $new_y;

    my $show_label = $track_config->get('has_labels') && $block->{'label'};

    if ($track_config->get('bumped')) {
      $row = $self->set_bump_row($block->{'start'}, $block->{'end'}, $show_label, $text_info);
    }
    next if $row == -1; ## Bumping code returns -1 if there's a problem 

    ## Feature
    my $block_height  = $track_config->get('height') || ($text_info->{'height'} + 2);
    my $label_height  = $show_label ? $text_info->{'height'} : 0;

    my $block_width   = $block->{'end'} - $block->{'start'} + 1;
    my $slice_width   = $image_config->container_width;
    $block_width      = $slice_width - $block->{'start'} if ($block_width > $slice_width);

    my $position  = {
                    'y'       => (($row + 1) * ($block_height + 4)) + $row * $label_height,
                    'width'   => $block_width,
                    'height'  => $block_height,
                    };
    
    $self->draw_block($block, $position);

    ## Optional label
    if ($show_label) {
      $new_y = $position->{'y'} + $block_height;
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

  ## Set parameters
  my $params = {
                  x            => $block->{'start'},
                  y            => $position->{'y'},
                  width        => $position->{'width'},
                  height       => $position->{'height'},
                  colour       => $block->{'colour'},
                  href         => $block->{'href'},
                  title        => $block->{'title'},
                  absolutey    => 1,
                };

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
