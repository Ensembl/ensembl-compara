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

package EnsEMBL::Draw::Style::Plot;

=pod
Renders a track as a Manhattan plot or continuous plot 
This module expects data in the following format:
  $data = [
            {
              'start'         => 123456,
              'end'           => 123789,
              'colour'        => 'red',                             # mandatory unless bordercolour set
              'score'         => 0.9,                               # mandatory (corresponds to the value of the point)
              'label'         => 'Feature 1',                       # optional
              'href'          => '/Location/View?r=123456-124789',  # optional   
            }
          ];
=cut

use strict;
use warnings;
no warnings 'uninitialized';

#use List::Util qw(min max);
use POSIX qw(floor ceil);

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
  ### Create all the glyphs required by this style
  ### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data          = $self->data;
  my $track_config  = $self->track_config;

  ## Set some track-wide variables
  my $height        = $track_config->get('height') || 40;
  my $plot_diameter = $track_config->get('plot_diameter') || 6; 

  # Left-hand side menu
  my $max_score = $track_config->get('max_score');
  my $min_score = $track_config->get('min_score');
  if (defined($max_score)) {
    $self->_draw_score(0, $max_score); # Max
  }
  if (defined($min_score)) {
    $self->_draw_score($height, $min_score); # Min
  }

  ## Single line? Build into singleton set.
  $data = [ $data ] if ref $data->[0] ne 'ARRAY';

  # Draw plots
  $self->draw_plots($height, $data, $plot_diameter);

}

sub draw_plots {
  my ($self, $height, $features, $focus_variant, $diam) = @_;

  foreach my $feature (@$features) {
    $self->draw_plot($height, $feature, $diam);
  }
  return @{$self->glyphs||[]};
}

sub draw_plot {
  my ($self, $height, $feature, $diam) = @_;

  my $pix_per_bp = $self->image_config->transform->{'scalex'};
  my $radius = $diam/2;

  my $score  = $feature->{'score'};
  my $start  = $feature->{'start'};
  my $end    = $feature->{'end'};
  my $colour = $feature->{'colour'};

  my $y = $self->get_y($height,$score) + $radius;
     $y = $height if ($y > $height);

  push @{$self->glyphs}, $self->Circle({
    x             => $start + $radius/$pix_per_bp,
    y             => $y,
    diameter      => $diam,
    colour        => $colour,
    absolutewidth => 1,
    filled        => 1,
  });

  # Invisible rectangle with a link to the ZMenu
  push @{$self->glyphs}, $self->Rect({
    x         => $start - $radius/$pix_per_bp,
    y         => $y - $diam,
    width     => $diam/$pix_per_bp,
    height    => $diam,
    href      => $feature->{'href'}
  });
}

sub _draw_score {
  my ($self, $y, $score) = @_;

  my $pix_per_bp = $self->image_config->transform->{'scalex'};

  my $text = ($score == 0) ? $score : sprintf('%.2f', $score);
  my $text_info   = $self->get_text_info($text);
  my $text_width  = $text_info->{'width'};
  my $text_height = $text_info->{'height'};
  my $twidth      = $text_width / $pix_per_bp;
  my $colour      = 'blue'; #$parameters->{'axis_colour'} || $self->my_colour('axis')  || 'blue';

  push @{$self->glyphs}, $self->Text({
    text          => $text,
    height        => $text_height,
    width         => $text_width,
    textwidth     => $text_width,
    halign        => 'right',
    colour        => $colour,
    y             => $y - $text_height/2 -2,
    x             => -2 - $text_width,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    font          => $self->{'font_name'},
    ptsize        => $self->{'font_size'}
  }), $self->Rect({
    height        => 0,
    width         => 5,
    colour        => $colour,
    y             => $y,
    x             => -8,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
  });
}

sub get_y {
  my $self    = shift;
  my $h       = shift;
  my $value   = shift;
  my $is_line = shift;

  my $y = $h - ($h * $value);

  return ($is_line) ? floor($y) : ceil($y);
}

1;
