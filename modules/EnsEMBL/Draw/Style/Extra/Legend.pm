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

package EnsEMBL::Draw::Style::Extra::Legend;

### 'Helper' module to draw legends on tracks

use strict;
use warnings;

use EnsEMBL::Draw::Utils::Text;

use parent qw(EnsEMBL::Draw::Style::Extra);

sub draw_gradient_key {
## Used by e.g. pvalue renderers, as gradient may vary from track to track
  my ($self, $gradient, $labels) = @_;
  my $track_config = $self->track_config;

  my $x_offset    = -10;
  my $y_offset    = 30;
  my $width       = 95;
  my $blocks      = scalar(@$gradient);
  my $block_size  = int( $width / $blocks );

  foreach my $i (1..$blocks) {
        
    my $x = $x_offset - $width + ($block_size * ($i-1));

    my $params = { 
                  x             => $x,
                  y             => $y_offset,
                  width         => $block_size,
                  height        => $block_size,
                  colour        => $gradient->[$i],
                  absolutey     => 1,
                  absolutex     => 1,
                  absolutewidth => 1,
    };
    push @{$self->glyphs}, $self->Rect($params);

    if (defined $labels->{$i-1}) {
        
      my $label         = $labels->{$i-1};
      $label            = sprintf '%.2f', $labels->{$i-1} if $label > int($label);
      my %font_details  = EnsEMBL::Draw::Utils::Text::get_font_details($self->image_config,'innertext', 1);
      my ($width,$height) = $self->get_text_dimensions($label, \%font_details);

      $params = {
                  x             => $x - ($width / 2),
                  y             => $y_offset + ($height / 2) + 1,
                  width         => $width,
                  height        => $height,
                  text          => $label,
                  halign        => 'left',
                  valign        => 'bottom',
                  colour        => 'black',
                  absolutey     => 1,
                  absolutex     => 1,
                  absolutewidth => 1,
                  %font_details,
      };
      push @{$self->glyphs}, $self->Text($params);
    }
  }
}

1;
