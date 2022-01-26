=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style::Feature::Alignment;

### Renders a track as a series of align blocks
use strict;

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Create each alignment as a block
### @param feature Arrayref - data for a genomic alignment block
### @param position Hashref - information about the feature's size and position
  my ($self, $block, $position, $count) = @_;
  #use Data::Dumper;
  #warn ">>> DRAWING ALIGNMENT ".Dumper($block);

  ## We only need the alignment for the current species
  my $feature = $block->{$self->image_config->{'species'}};
  return unless $feature;
  my $debug = $self->track_config->get('DEBUG_RAINBOW');
  if ($debug) {
    $feature->{'colour'} = $self->rainbow($count);
  }
  elsif (ref($feature->{'colour'}) eq 'ARRAY') {
    my @colours = @{$feature->{'colour'}||[]};
    my $i = $count % scalar(@colours);;
    $feature->{'colour'} = $colours[$i];
  }
  #warn "@@@ ACTUAL COLOUR ".$feature->{'colour'}."\n\n";
  ## Historically, width is saved in the position hash rather than the feature itself
  $position->{'width'} = $feature->{'end'} - $feature->{'start'};

  my $glyph = $self->SUPER::draw_feature($feature, $position);
  ## Now add the 'tag' that joins the two blocks
  if (scalar(@{$block->{'connections'}||[]})) {
    my $connection_colour = $debug ? $feature->{'colour'} : undef;
    $self->draw_connections($block->{'connections'}, $glyph, {
                                                              colour => $connection_colour,
                                                              count  => $count,
                                                              }); 
  }
}

sub draw_connections {
  ## Set up a "join tag" to display mapping between align blocks
  ## This will actually be rendered into a glyph later, when all the glyphsets are drawn
  my ($self, $connections, $glyph, $args) = @_;

  my $strand  = $self->track_config->get('drawn_strand');
  my $part    = $strand == 1 ? 1 : 0;
  my $y       = $strand == 1 ? 0 : 1;  
  my @shapes = (
                [[0,0],[0,1],[1,1],[1,0]], # circuit makes quadrilateral,
                [[0,0],[0,1],[1,0],[1,1]], # but zigzag makes cross
                );

  my @colours = @{$connections->[0]{'colour'}||[]};
  my $i = $args->{'count'} % scalar(@colours);;
  my $colour = $args->{'colour'} || $colours[$i];

  foreach my $connection (@$connections) {
    foreach my $s (@{$shapes[$connection->{'cross'}]}) {
      next unless $s->[0] == $part; # only half of it is on each track

      my $params = {
                    x     => $s->[1],
                    y     => $y, 
                    z     => 1000,
                    col   => $colour,
                    style => 'fill',
                    alpha => 0.6,
                    };  
      $self->add_connection($glyph, $connection->{'key'}, $params);
    }
  }
}

1;
