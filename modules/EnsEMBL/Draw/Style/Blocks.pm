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
              'href'          => '/Location/View?r=123456-124789',  # optional  
              'label'         => 'Feature 1',                       # optional
              'label_colour'  => 'red',                             # optional
            },
            {
              'start'         => 123654,
              'end'           => 123987,
              'colour'        => 'blue',
              'href'         => '/Location/View?r=123654-124987',   # optional  
              'label'         => 'Feature 2',                       # optional
              'label_colour'  => 'blue',                            # optional
            },
          ];
=cut

use strict;
use warnings;

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
  my $self = shift;

  my $data          = $self->data;
  my $track_config  = $self->track_config;
  
  foreach my $block (@$data) {
    my $text_info = $self->get_text_info($block->{'label'});

    ## Feature (non-bumped)
    my $height = $self->track_config->{'height'} || ($text_info->{'height'} + 2);
    $self->draw_block($block, {'height' => $height});

    ## Optional label (needs to be bumped)
    if ($track_config->get('has_labels') && $block->{'label'}) {
      my $position = {
                        'y'       => $height + 4, 
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
  my ($self, $block, $position) = @_;


  ## Set parameters
  my $params = {
                  x            => $block->{'start'},
                  y            => 0,
                  width        => $block->{'end'} - $block->{'start'} + 1,
                  height       => $position->{'height'},
                  colour       => $block->{'colour'},
                  absolutey    => 1,
                };
  $params->{'href'} = $block->{'href'} if $block->{'href'};

  push @{$self->glyphs}, $self->Rect($params);
}

sub add_label {
### Create a text label
  my ($self, $block, $position) = @_;

  my $label_colour = $block->{'label_colour'} || $block->{'colour'} || 'black';
  my $label = {
                font      => $self->{'font_name'},
                colour    => $label_colour,
                height    => $self->{'font_size'},
                ptsize    => $self->{'font_size'},
                text      => $block->{'label'},
                x         => $block->{'start'},
                y         => $position->{'y'},
                width     => $position->{'width'},
                height    => $position->{'height'},
                absolutey => 1,
              };
  push @{$self->glyphs}, $self->Text($label);
}

1;
