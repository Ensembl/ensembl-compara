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

package EnsEMBL::Draw::Style::Plot::LD;

=pod
Renders a track as a Manhattan plot or continuous plot for Linkage Disequilibrium (LD) data
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

use List::Util qw(min max);

use parent qw(EnsEMBL::Draw::Style::Plot);

sub create_glyphs {
### Create all the glyphs required by this style
### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data          = $self->data;
  my $track_config  = $self->track_config;

  my $height        = $track_config->get('height') || 40;

  # Adjusts the height of the basal horizontal line because the values in pixels can't render the data with a high accuracy
  my $adjusted_height = $height - 1;

  # Horizontal baseline
  if ($track_config->get('baseline_zero')) {
    $self->draw_h_line(0);       # Top line
    $self->draw_h_line($adjusted_height); # Baseline
  }

  # Left-hand side menu
  my $max_score = 1;
  my $min_score = 0;
  $self->_draw_score(0, $max_score,$track_config->get('max_score_label')); # Max
  $self->_draw_score($adjusted_height, $min_score,$track_config->get('min_score_label')); # Min

  # Draw plots
  my $options = {
                'focus_variant'   => $track_config->get('focus_variant'),
                'diameter'        => $track_config->get('plot_diameter') || 6,
                'filled'          => 1,
                'height'          => $height,
                'adjusted_height' => $adjusted_height,
                };
  foreach my $track (@$data) {
    $self->draw_plots($track, $options);
  }

  # Horizontal mark line
  if (defined $track_config->get('h_mark')) {
    $self->draw_mark_line($track_config->get('h_mark'), $height,
                          $track_config->get('h_mark_label'));
  }
  return @{$self->glyphs||[]};
}


sub draw_mark_line {
  my ($self, $v_value, $height, $label) = @_;

  $label //= $v_value;
  my $vclen      = $self->image_config->container_width;
  my $pix_per_bp = $self->image_config->transform_object->scalex;

  # Mark line
  my $line_colour = $self->track_config->get('line') || 'red';
  my $y_line = $self->get_y($height, $v_value, 1);

  push @{$self->glyphs}, $self->Line({
    x         => 0,
    y         => $y_line,
    width     => $vclen,
    height    => 0,
    colour    => $line_colour,
    absolutey => 1,
    dotted    => 1
  });

  # Mark label
  my $text_info   = $self->get_text_info($v_value);
  my $text_width  = $text_info->{'width'};
  my $text_height = $text_info->{'height'};
  my $twidth      = $text_width / $pix_per_bp;

  my $y_value = $y_line - $text_height - 2;
  if ($y_value < 0) {
    $y_value = $y_line + 2;
  }

  push @{$self->glyphs}, $self->Text({
    x         => -16/$pix_per_bp,
    y         => $y_value,
    width     => $twidth,
    textwidth => $text_width,
    height    => $text_height,
    halign    => 'center',
    colour    => $line_colour,
    text      => $label,
    absolutey => 1,
    font      => $self->{'font_name'}, 
    ptsize    => $self->{'font_size'}
  });
}


sub draw_h_line {
  my ($self, $height) = @_;

  my $vclen = $self->image_config->container_width;  

  push @{$self->glyphs}, $self->Line({
    x         => 0,
    y         => $height,
    width     => $vclen,
    height    => 0,
    colour    => '#4c4cff',
    absolutey => 1,
    dotted    => 1
  });
}


sub draw_plots {
  my ($self, $track, $options) = @_;
  my $focus_variant = $options->{'focus_variant'};

  foreach my $feature (@{$track->{'features'}||[]}) {
    # Selected variant
    if ($focus_variant && $feature->{'label'} eq $focus_variant) {
      $self->draw_focus_variant($feature, $options);
    }
    else {
      $self->draw_plot($feature, $options);
    }
  }
}

sub draw_focus_variant {
  my ($self, $feature, $options) = @_;

  my $pix_per_bp = $self->{'pix_per_bp'};

  my $start     = $feature->{'start'};
  my $end       = $feature->{'end'};
  my $width     = $end - $start + 1;
  my $height    = $options->{'adjusted_height'};

  my $t_width   = 6 / $pix_per_bp;
  my $t_height  = 8;

  # Vertical line
  push @{$self->glyphs}, $self->Rect({
    x      => $start - $width/2,
    y      => -$t_height,
    width  => $width,
    height => $height + $t_height,
    colour => 'black',
    z      => 10,
    href   => $feature->{'href'}
  });

  # Triangle mark
  push @{$self->glyphs}, $self->Triangle({
    mid_point  => [ $start, -($t_height/2) ],
    colour     => 'black',
    absolutey  => 1,
    width      => $t_width,
    height     => $t_height,
    z          => 12,
    direction  => 'down',
    href       => $feature->{'href'}
  });

  my $label        = $feature->{'label'};
  my $label_info   = $self->get_text_info($label);
  my $label_width  = $label_info->{'width'};
  my $label_height = $label_info->{'height'};
  my $lwidth       = $label_width / $pix_per_bp;

  # Variant text lable
  push @{$self->glyphs}, $self->Text({
    x         => $start + $t_width + $width,
    y         => 0 - $label_height - 4,
    width     => $lwidth,
    textwidth => $label_width,
    height    => $label_height,
    halign    => 'center',
    colour    => 'black',
    text      => $label,
    absolutey => 1,
    font      => $self->{'font_name'},
    ptsize    => $self->{'font_size'}
  });
}

1;
