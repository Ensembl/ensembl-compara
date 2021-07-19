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

package EnsEMBL::Draw::Style::Feature::MultiBlocks;

=pod

Renders a track as a series of rectangular blocks, each of which may
consist of a number of blocks in different colours. For example regulatory
features showing motifs, flanks, etc.

=cut

use parent qw(EnsEMBL::Draw::Style::Feature);


sub draw_feature {
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  return unless ($feature->{'colour'});
  my $total_height = $position->{'height'};

  ## Need to set y to 0 here, as a composite's components' y-coords are _added_ to this base y
  my $composite = $self->Composite({
                                      y       => 0,
                                      height  => $position->{'height'},
                                      title   => $feature->{'title'},
                                      href    => $feature->{'href'},
                                      class   => 'group',
                                  });


  ## Set default parameters
  my %defaults = (
                    y           => $position->{'y'},
                    height      => $position->{'height'},
                    absolutey   => 1,
                  );

  ## Draw main feature 
  my %params                = %defaults; 
  my $x                     = $feature->{'start'};
  $x                        = 0 if $x < 0;
  $params{'x'}              = $x;
  $params{'width'}          = $position->{'width'};
  $params{'colour'}         = $feature->{'colour'};
  $params{'bordercolour'}   = $feature->{'bordercolour'};
  $params{'pattern'}        = $feature->{'pattern'};
  $params{'patterncolour'}  = $feature->{'patterncolour'};
  $composite->push($self->Rect(\%params));

  ## Draw internal structure, e.g. motif features
  if ($feature->{'extra_blocks'} && $self->track_config->get('display_structure')) {
    foreach my $element (@{$feature->{'extra_blocks'}}) {
      ## Check in case outside viewport
      next if ($element->{'end'} < 0 || $element->{'start'} > $position->{'image_width'});
      $composite->push($self->Rect({
                                    x             => $element->{'start'} - 1,
                                    width         => $element->{'end'} - $element->{'start'} + 1,
                                    colour        => $element->{'colour'},
                                    pattern       => $element->{'pattern'},
                                    patterncolour => $element->{'patterncolour'},
                                    %defaults
                                    }
      ));
    }
  }

  push @{$self->glyphs}, $composite;
  return $total_height;
}

sub configure_bumping {
  my ($self, $features) = @_;
  
  foreach my $f (@$features) {
    ## Set defaults
    $f->{'_bstart'} = $f->{'start'};
    $f->{'_bend'}   = $f->{'end'};

    ## Do we have any extra blocks outside the main feature?
    if ($f->{'extra_blocks'}) {
      foreach (@{$f->{'extra_blocks'}}) {
        $f->{'_bstart'} = $_->{'start'} if $_->{'start'} < $f->{'_bstart'};
        $f->{'_bend'} = $_->{'end'} if $_->{'end'} > $f->{'_bend'};
      }
    }
  }
}

1;
