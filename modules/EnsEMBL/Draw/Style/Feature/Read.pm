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
                                    'title'   =>  $feature->{'label'},
                                    });

  ## First the simple feature block
  my $x = $feature->{'start'};
  $x    = 0 if $x < 0;
  my $params = {
                  x          => $x,
                  y          => $position->{'y'},
                  width      => $position->{'width'},
                  height     => $height,
                  href       => $feature->{'href'},
                };
  $params->{'colour'}       = $feature->{'colour'} if $feature->{'colour'};
  $params->{'bordercolour'} = $feature->{'bordercolour'} if $feature->{'bordercolour'};
  #use Data::Dumper; warn Dumper($params);
  $composite->push($self->Rect($params));

  ## Add an arrow if defined
  if (keys %{$feature->{'arrow'}}) {
    ## horizontal
    $params = {
    #$composite->push($self->Rect({
        'x'         => $feature->{'arrow'}{'position'}, 
        'y'         => $position->{'y'},
        'width'     => $feature->{'arrow'}{'width'},
        'height'    => $feature->{'arrow'}{'thickness'}, 
        'colour'    => $feature->{'arrow'}{'colour'},
    #}));
    };
  #use Data::Dumper; warn Dumper($params);
    $composite->push($self->Rect($params));

    if ($height == 8) {
      ## vertical
    $params = {
    #  $composite->push($self->Rect({
          'x'         => $feature->{'arrow'}{'position'}, 
          'y'         => $position->{'y'},
          'width'     => $feature->{'arrow'}{'thickness'} / $self->{'pix_per_bp'},  
          'height'    => $height,
          'colour'    => $feature->{'arrow'}{'colour'},
    #}));
    };
  use Data::Dumper; warn Dumper($params);
    $composite->push($self->Rect($params));
    }
  }

  push @{$self->glyphs}, $composite; 
}

1;
