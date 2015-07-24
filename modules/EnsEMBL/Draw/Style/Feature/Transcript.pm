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

package EnsEMBL::Draw::Style::Feature::Transcript;

### Renders a track as a series of exons and introns 

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Create each feature as a set of glyphs: blocks plus joins
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  ## In case we're trying to draw a feature with no internal structure,
  ## revert to parent method, which is much simpler!
  my $structure = $feature->{'structure'};
  if (!$structure) {
    $self->SUPER::draw_feature($feature, $position);
  }

  ## Basic parameters for all parts of the feature
  my $feature_start = $feature->{'start'};
  my $current_x = $feature_start;
  $current_x    = 0 if $current_x < 0;

  my $colour    = $feature->{'colour'};
  my $join      = $feature->{'join_colour'} || $feature->{'bordercolour'} || $colour;

  my $track_config = $self->track_config;

  my %defaults = (
                  y            => $position->{'y'},
                  height       => $position->{'height'},
                  href         => $feature->{'href'},
                  title        => $feature->{'title'},
                  absolutey    => 1,
                );

  use Data::Dumper;

  my %previous;

  foreach (@$structure) {

    my ($start, $width, $coding) = @$_; 

    ## Join this block to the previous one
    if (keys %previous) {
      my %params = %defaults;
      my $end = $previous{'x'} + $previous{'width'};
      $params{'x'}      = $end;
      $params{'width'}  = $start - $end;

      if ($alpha) {
        $params{'colour'} = $colour;
        $params{'alpha'}  = $alpha;
      }
      else {
        $params{'bordercolour'} = $join;
      }
      #warn ">>> DRAWING JOIN ".Dumper(\%params);
      push @{$self->glyphs}, $self->Rect(\%params);
      
    }

    ## Now draw the next chunk of structure
    my %params = %defaults;

    $params{'x'}      = $start;
    $params{'width'}  = $width;

    $params{'colour'} = $colour;
    #warn ">>> DRAWING BLOCK ".Dumper(\%params);
    push @{$self->glyphs}, $self->Rect(\%params);
    $current_x += $width;
    %previous = %params;
  }

}

1;
