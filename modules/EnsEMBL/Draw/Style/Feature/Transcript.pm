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
  my $current_x     = $feature_start;
  $current_x        = 0 if $current_x < 0;

  my $colour        = $feature->{'colour'};
  my $join_colour   = $feature->{'join_colour'} || $colour;

  my $track_config  = $self->track_config;

  my %defaults = (
                  y            => $position->{'y'},
                  height       => $position->{'height'},
                  href         => $feature->{'href'},
                  title        => $feature->{'title'},
                  absolutey    => 1,
                );

  use Data::Dumper;

  my $image_width = $position->{'image_width'};
  my %previous;

  foreach (@$structure) {

    my $last_element = 0;

    ## Join this block to the previous one
    if (keys %previous) {
      my %params        = %defaults;
      my $start         = $previous{'x'} + $previous{'width'};
      $params{'x'}      = $start;
      my $end           = $_->{'start'};
      my $width         = $end - $start;
      if ($end > $image_width) {
        $width          = $image_width - $start;
        $last_element   = 1;
      }
      $params{'width'}  = $width;

      $params{'colour'} = $join_colour;
      warn ">>> DRAWING INTRON ".Dumper(\%params);
      push @{$self->glyphs}, $self->Intron(\%params);
      
    }
    last if $last_element;

    ## Now draw the next chunk of structure
    my %params = %defaults;

    my $start = $_->{'start'};
    my $end   = $_->{'end'};
    $params{'x'}      = $start;
    $params{'width'}  = $end - $start;

    ## Only draw blocks that appear on the image!
    unless ($end < 0 || $start > $position->{'image_width'}) {
      $params{'colour'} = $colour;
      if ($_->{'non_coding'}) {
        $self->draw_noncoding_block(%params);
      }
      elsif ($_->{'utr_5'}) {
        $params{'width'} = $_->{'utr_5'};
        $self->draw_noncoding_block(%params);
        $params{'x'}    += $_->{'utr_5'};
        $params{'width'} = $_->{'width'} - $_->{'utr_5'};
        $params{'colour'} = $colour;
        $self->draw_coding_block(%params);
      }
      elsif ($_->{'utr_3'}) {
        $params{'width'} = $_->{'utr_3'};
        $self->draw_coding_block(%params);
        $params{'x'}    += $_->{'utr_3'};
        $params{'width'} = $_->{'width'} - $_->{'utr_3'};
        $self->draw_noncoding_block(%params);
      }
      else {
        $self->draw_coding_block(%params);
      }
    }
    $current_x += $width;
    %previous = %params;
  }

}

sub draw_coding_block {
  my ($self, %params) = @_;
  warn ">>> DRAWING CODING BLOCK ".Dumper(\%params);
  push @{$self->glyphs}, $self->Rect(\%params);
}

sub draw_noncoding_block {
  my ($self, %params) = @_;
  $params{'bordercolour'} = $params{'colour'};
  delete $params{'colour'};
  $params{'height'} = $params{'height'} - 2;
  $params{'y'} += 1;
  warn ">>> DRAWING NON-CODING BLOCK ".Dumper(\%params);
  push @{$self->glyphs}, $self->Rect(\%params);
}

1;
