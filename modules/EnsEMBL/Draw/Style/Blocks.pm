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
on one line (i.e. not stacked or bumped)

This module expects data in the following format:

  $data = [
            {
              'start'         => 123456,
              'end'           => 123789,
              'colour'        => 'red',
              'url'           => '',            # optional  
              'label'         => 'Feature 1',   # optional
              'label_colour'  => 'red',         # optional
            },
            {
              'start'         => 123654,
              'end'           => 123987,
              'colour'        => 'blue',
              'url'           => '',            # optional  
              'label'         => 'Feature 1',   # optional
              'label_colour'  => 'red',         # optional
            },
          ];
=cut

use strict;
use warnings;

use parent qw(EnsEMBL::Draw::Style);

sub glyphs {
  my $self = shift;

  my $data          = $self->data;
  my $track_config  = $self->track_config;
  my @glyphs        = ();

  foreach my $datum (@$data) {

    ## Map raw coordinates onto image
    my ($start, $end) = $self->map_to_image($datum->{'start'}, $datum->{'end'});

    ## Set parameters
    my $params = {
                    x            => $start,
                    y            => 0,
                    width        => $end - $start + 1,
                    height       => $track_config->{'glyph_height'},
                    colour       => $datum->{'colour'},
                    absolutey    => 1,
                  };
    $params->{'href'} = $datum->{'url'} if $datum->{'url'};

    ## Create glyph
    push @glyphs, $self->Rect($params);

    ## Optional label
    if ($track_config->{'has_labels'} && $datum->{'label'}) {
      my $label_colour = $datum->{'label_colour'} || $datum->{'colour'} || 'black';
      my @text_info = $self->get_text_width(0, $datum->{'label'}, '', 
                                              font   => $self->{'font_name'}, 
                                              ptsize => $self->{'font_size'});
      my $label = {
                    font      => $self->{'font_name'},
                    colour    => $label_colour,
                    height    => $self->{'font_size'},
                    ptsize    => $self->{'font_size'},
                    text      => $datum->{'label'},
                    x         => $start,
                    y         => $track_config->{'glyph_height'} + 4,
                    width     => $text_info[2],
                    height    => $text_info[3],
                    absolutey => 1,
                  };
      push @glyphs, $self->Text($label);
    }


  }

  return @glyphs;
}
