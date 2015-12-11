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

  ## Set some track-wide variables
  my $height        = $track_config->get('height') || 40;
  my $focus_variant = $track_config->get('focus_variant');
  my $plot_diameter = $track_config->get('plot_diameter') || 6; 
  
  # Horizontal mark line
  if ($track_config->get('h_mark')) {
    $self->draw_mark_line($track_config->get('h_mark'), $height);
  }

  # Horizontal baseline
  if ($track_config->get('baseline_zero')) {
    $self->draw_baseline($height);
  }

  # Left-hand side menu
  my $max_score = 1;
  my $min_score = 0;
  $self->_draw_score(0, $max_score); # Max
  $self->_draw_score($height, $min_score); # Min

  # Draw plots
  $self->draw_plots($height, $data, $focus_variant, $plot_diameter);

}


sub draw_mark_line {
  my ($self, $v_value, $height) = @_;

  my $vclen      = $self->image_config->container_width;
  my $pix_per_bp = $self->image_config->transform->{'scalex'};

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
    x         => 4/$pix_per_bp,
    y         => $y_value,
    width     => $twidth,
    textwidth => $text_width,
    height    => $text_height,
    halign    => 'center',
    colour    => $line_colour,
    text      => $v_value,
    absolutey => 1,
    font      => $self->{'font_name'}, 
    ptsize    => $self->{'font_size'}
  });
}


sub draw_baseline {
  my ($self, $height) = @_;

  my $vclen = $self->image_config->container_width;  

  push @{$self->glyphs}, $self->Line({
    x         => 0,
    y         => $height,
    width     => $vclen,
    height    => 0,
    colour    => '#CCCCCC',
    absolutey => 1,
  });
}

sub draw_plots {
  my ($self, $height, $features, $focus_variant, $diam) = @_;

  foreach my $feature (@$features) {

    # Selected variant
    if ($focus_variant && $feature->{'label'} eq $focus_variant) {
      $self->draw_focus_variant($height, $feature);
    }
    else {
      $self->draw_plot($height, $feature, $diam);
    }
  }
  return @{$self->glyphs||[]};
}

sub draw_focus_variant {
  my ($self, $height, $feature) = @_;

  my $pix_per_bp = $self->image_config->transform->{'scalex'};

  my $start = $feature->{'start'};
  my $end   = $feature->{'end'};

  my $width = $end - $start + 1;
  push @{$self->glyphs}, $self->Rect({
    x      => $start - $width/2,
    y      => 0,
    width  => $width,
    height => $height,
    colour => 'black',
    href   => $feature->{'href'}
  });
  
  my $label        = $feature->{'label'};
  my $label_info   = $self->get_text_info($label);
  my $label_width  = $label_info->{'width'};
  my $label_height = $label_info->{'height'};
  my $lwidth       = $label_width / $pix_per_bp;

  push @{$self->glyphs}, $self->Text({
    x         => $start + $width + 4/$pix_per_bp,
    y         => ($height - $label_height) / 2,
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
