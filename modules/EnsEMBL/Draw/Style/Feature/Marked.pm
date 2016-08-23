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

package EnsEMBL::Draw::Style::Feature::Marked;

=pod
Renders a track as a series of blocks with 'marks' - additional glyphs
that provide supplementary information

Currently available marks:

  * triangle

=cut

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Draw a block with optional tags
  my ($self, $feature, $position) = @_;
  #use Data::Dumper; warn Dumper($feature);

  return unless ($feature->{'colour'} || $feature->{'bordercolour'});

  if ($feature->{'marks'}) {
    $self->draw_composite($feature, $position); 
  }
  else {
    $self->SUPER::draw_feature($feature, $position);
  }
}

sub draw_composite {
### Create a Composite glyph with optional 'marks'
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  my $composite = $self->Composite;

  ## Set parameters
  my $x = $feature->{'start'};
  $x    = 1 if $x < 1;
  my $params = {
                  x            => $x-1,
                  y            => $position->{'y'},
                  width        => $position->{'width'},
                  height       => $position->{'height'},
                  href         => $feature->{'href'},
                  title        => $feature->{'title'},
                  absolutey    => 1,
                };
  $params->{'colour'}       = $feature->{'colour'} if $feature->{'colour'};
  $params->{'bordercolour'} = $feature->{'bordercolour'} if $feature->{'bordercolour'};

  $composite->push($self->Rect($params));

  foreach my $mark (@{$feature->{'marks'}}) {
    my $method = 'add_'.$mark->{'style'};
    $self->$method($composite, $position, $mark);
  }

  push @{$self->glyphs}, $composite;
}


sub add_triangle {
### Add a triangular glyph to a composite
### @param EnsEMBL::Draw::Glyph::Composite
### @param position - hashref describing the position of the main feature
### @param args     - hashref describing the mark to be added
  my ($self, $composite, $position, $args) = @_;

  my $w = $args->{'width'} || 6;
  my $h = $args->{'height'} || 5;

  my $x = $args->{'start'};
  my $y = $args->{'above'} ? ($position->{'y'} - $h - 2) : ($position->{'y'} + $h + 2);

  ## Triangle always returns two glyphs - the visible shape and a clickable area,
  ## but we don't need the latter for this composite
  my $mark = $self->Triangle({
                                  width         => $w,
                                  height        => $h,
                                  direction     => $args->{'direction'},
                                  mid_point     => [ $x, $y ],
                                  colour        => $args->{'colour'},
                                  absolutex     => 1,
                                  absolutey     => 1,
                                  no_rectangle  => 1,
                              });

  $composite->push($mark);
}

1;
