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

package EnsEMBL::Draw::Style::Blocks::Joined;

=pod
Renders a track as a series of simple rectangular blocks
joined by horizontal "borders"

=cut

use parent qw(EnsEMBL::Draw::Style::Blocks);

sub draw_block {
### Create a set of glyphs joined by horizontal lines
### @param block Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $block, $position) = @_;

  ## In case we're trying to draw a feature with no internal structure,
  ## revert to parent method, which is much simpler!
  my $cigar_string = $block->{'cigar_string'};
  if (!$cigar_string) {
    $self->SUPER::draw_block($block, $position);
  }

  ## Basic parameters for all part of the feature
  my $start     = $block->{'start'};
  $start        = 0 if $start < 0;
  my $current_x = $start;

  my $colour    = $block->{'colour'};
  my $join      = $block->{'join_colour'} || $block->{'bordercolour'} || $colour;

  my $track_config = $self->track_config;
  my $alpha        = $track_config->get('alpha');

  my %defaults = (
                  y            => $position->{'y'},
                  height       => $position->{'height'},
                  href         => $block->{'href'},
                  title        => $block->{'title'},
                  absolutey    => 1,
                );

  ## Parse the cigar string, splitting up into an array
  ## like ('10M','2I','30M','I','M','20M','2D','2020M');
  ## original string - "10M2I30MIM20M2D2020M"
  my @cigar = $cigar_string =~ /(\d*[MDImUXS=])/g;

use Data::Dumper;

  foreach (@cigar) {
    my %params = %defaults;

    ## Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
    ## representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    ## If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($len, $type) = /^(\d+)([MDImUXS=])/ ? ($1, $2) : (1, $_);

    $params{'x'}      = $current_x;
    $params{'width'}  = $len;

    # If a match/mismatch - draw box
    if ($type =~ /^[MmU=X]$/) {
      $params{'colour'} = $colour;
      #warn ">>> DRAWING BLOCK ".Dumper(\%params);
    }
    ## Otherwise draw join
    else {
      if ($alpha) {
        $params{'colour'} = $colour;
        $params{'alpha'}  = $alpha;
      }
      else {
        $params{'bordercolour'} = $join;
      }
      #warn ">>> DRAWING JOIN ".Dumper(\%params);
    }
    push @{$self->glyphs}, $self->Rect(\%params);
    $current_x += $len;
  }

}

1;
