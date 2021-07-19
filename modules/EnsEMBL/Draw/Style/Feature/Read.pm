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

package EnsEMBL::Draw::Style::Feature::Read;

=head2

  Description: Draws sequence reads for BAM files

=cut

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Create a composite glyph to represent an aligned read
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;
  return unless $feature->{'colour'};

  my $height      = $position->{'height'};
  my $composite   = $self->Composite({
                                    'height'  => $height,
                                    'title'   => $feature->{'title'},
                                    'href'    => $feature->{'href'},
                                    });

  ## First the simple feature block
  my $x = $feature->{'start'};
  $x    = 0 if $x < 0;
  my $y = $position->{'y'} + $self->track_config->get('y_offset');
  my $params = {
                  x          => $x,
                  y          => $y,
                  width      => $position->{'width'},
                  height     => $height,
                };
  $params->{'colour'}       = $feature->{'colour'} if $feature->{'colour'};
  $params->{'bordercolour'} = $feature->{'bordercolour'} if $feature->{'bordercolour'};
  $composite->push($self->Rect($params));

  ## Add an arrow if defined
  if ($feature->{'arrow'}{'position'}) {
    my $thickness = 1 / $self->{'pix_per_bp'};
    ## Align with correct end of feature
    my $arrow_x = $feature->{'arrow'}{'position'} eq 'start' ? $x : $feature->{'end'} - $thickness;

    if ($height == 8) {
      ## vertical
      $composite->push($self->Rect({
          'x'         => $arrow_x,
          'y'         => $y,
          'width'     => $thickness,  
          'height'    => $height,
          'colour'    => $feature->{'arrow'}{'colour'},
      }));
    }

    ## horizontal
    $arrow_x = $feature->{'arrow'}{'position'} eq 'start' ? $arrow_x : $arrow_x - $thickness;
    $composite->push($self->Rect({
        'x'         => $arrow_x, 
        'y'         => $y,
        'width'     => $thickness * 2,
        'height'    => 1, 
        'colour'    => $feature->{'arrow'}{'colour'},
    }));
  }

  ## Add inserts 
  if (scalar @{$feature->{'inserts'}}) {
    my $insert_colour = $self->track_config->get('insert_colour');
    foreach (@{$feature->{'inserts'}}) {
      $composite->push($self->Rect({
                                    'x'         => $x + $_,
                                    'y'         => $y,
                                    'width'     => 1,
                                    'height'    => $height,
                                    'colour'    => $insert_colour,
                                    'zindex'    => 10,
      }));
    }
  }

  ## Add consensus base-pair labels
  if ($feature->{'consensus'}) {
    foreach (@{$feature->{'consensus'}}) {
      $composite->push($self->Text({
                                    'x'         => $x + $_->[0],
                                    'y'         => $y,
                                    'width'     => 1,
                                    'font'      => 'Tiny',
                                    'text'      => $_->[1],
                                    'colour'    => $_->[2],
                                    }));
    }
  }

  push @{$self->glyphs}, $composite; 
  return $height;
}

1;
