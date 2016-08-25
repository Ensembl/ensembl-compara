=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style::Feature::Variant;

=pod

Renders a variation track with variants drawn differently depending on what type they are. 

Whilst we try to keep biological information out of the lower-level drawing code as much 
as possible, the density of the variation tracks means we have to avoid looping through
the array of features. Hence this module decides how to draw each variant, rather than
the glyphset. 

=cut

use List::Util qw(min);

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Draw a block with optional tags
  my ($self, $feature, $position) = @_;

  return unless ($feature->{'colour'} || $feature->{'bordercolour'});

  ## SNPs have two kinds of "label" - an ambiguity code which may be drawn on the feature,
  ## and an ID which is used as a normal label
  $feature->{'overlay_colour'} = $feature->{'label_colour'};
  $feature->{'label_colour'} = $feature->{'colour'};

  if ($feature->{'type'}) {
    my $method = 'draw_'.$feature->{'type'};
    $self->$method($feature, $position) if $self->can($method); 
  }
  else {
    $self->SUPER::draw_feature($feature, $position);
  }
}

sub draw_insertion {
### Draw a variant of type 'insertion'
### @param feature  - hashref describing the feature 
### @param position - hashref describing the position of the main feature
  my ($self, $feature, $position) = @_;

  my $composite = $self->Composite;

  ## Draw a narrow line to mark the insertion point
  my $x = $feature->{'start'};
  $x    = 1 if $x < 1;
  my $params = {
                  x         => $x - 1,
                  y         => $position->{'y'},
                  width     => $position->{'width'} / (2 * $self->{'pix_per_bp'}),
                  height    => $position->{'height'},
                  href      => $feature->{'href'},
                  colour    => $feature->{'colour'},
                  title     => $feature->{'title'},
                };
  $composite->push($self->Rect($params));

  ## invisible box to make inserts more clickable
  my $width = min(1, 16 / $self->{'pix_per_bp'});
  $composite->push($self->Rect({
                                  x         => $x - 1 - $position->{'width'} / 2,
                                  y         => $position->{'y'},
                                  width     => $width,
                                  height    => $position->{'height'} + 2,
                                  href      => $feature->{'href'},
                                }));

  ## Draw a triangle below the line to identify it as an insertion
  ## Note that we can't add the triangle to the composite, for Reasons
  my $y = $position->{'y'} + $position->{'height'};
  $params = {
              width         => int(4 / $self->{'pix_per_bp'}),
              height        => 3,
              direction     => 'up',
              mid_point     => [ $x - 0.5, $y ],
              colour        => $feature->{'colour'},
              absolutey     => 1,
              no_rectangle  => 1,
             };
  my $triangle = $self->Triangle($params);

  ## OK, all done!
  push @{$self->glyphs}, $composite, $triangle;
}

1;
