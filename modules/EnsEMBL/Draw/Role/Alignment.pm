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

package EnsEMBL::Draw::Role::Alignment;

### Role for tracks that draw individual features aligned to the genome

use Role::Tiny;

## Renderers which tweak the standard track style

sub render_as_alignment_nolabel {
  my $self = shift;
  $self->draw_features;
}

sub render_as_alignment_label {
  my $self = shift;
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub render_as_transcript_nolabel {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->draw_features;
}

sub render_as_transcript_label {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub render_interaction {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Interaction']);
  $self->{'my_config'}->set('bumped', 0); 
  $self->draw_features;
  ## Limit track height to that of biggest arc
  my $max_height  = $self->{'my_config'}->get('max_height');
  $self->{'maxy'} = $max_height if $max_height;
}


sub render_half_height {
  my $self = shift;
  my $height = $self->my_config('height') ? $self->my_config('height') / 2 : 4;
  $self->{'my_config'}->set('height', $height);
  $self->{'my_config'}->set('depth', 20);

  $self->draw_features;
}

sub render_stack {
  my $self = shift;
  ## Show as a deep stack of densely packed features
  $self->{'my_config'}->set('height', 1);
  $self->{'my_config'}->set('vspacing', 0);
  $self->{'my_config'}->set('depth', 40);
  ## Draw joins as 50% transparency, not borders
  $self->{'my_config'}->set('alpha', 0.5);

  $self->draw_features;
}

sub render_unlimited {
  my $self = shift;
  ## Show as a very deep stack of densely packed features
  $self->{'my_config'}->set('height', 1);
  $self->{'my_config'}->set('vspacing', 0);
  $self->{'my_config'}->set('depth', 1000);
  ## Draw joins as 50% transparency, not borders
  $self->{'my_config'}->set('alpha', 0.5);

  $self->draw_features;
}

sub render_ungrouped {
  my $self = shift;
  $self->{'my_config'}->set('no_join', 1);
  $self->{'my_config'}->set('bumped', 0);
  $self->draw_features;
}


sub convert_cigar_to_blocks {
  ## The drawing code shouldn't care what a cigar string is!
  my ($self, $cigar_string, $feature_start) = @_;
  my $blocks = [];

  my $current_start = $feature_start;

  ## Parse the cigar string, splitting up into an array
  ## like ('10M','2I','30M','I','M','20M','2D','2020M');
  ## original string - "10M2I30MIM20M2D2020M"
  my @cigar = $cigar_string =~ /(\d*[MDImUXS=])/g;

  foreach (@cigar) {
    ## Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ] 
    ## representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    ## If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($length, $type) = /^(\d+)([MDImUXS=])/ ? ($1, $2) : (1, $_);

    my $start = $current_start;

    # If a match/mismatch, create a structure block
    if ($type =~ /^[MmU=X]$/) {
      push @$blocks, [$start, $length];
    }
    $current_start += $length;
  }

  return $blocks;
}

1;
