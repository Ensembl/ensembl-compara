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

package EnsEMBL::Draw::Style::Feature::Structured;

### Renders a track as a series of features with internal structure
### Blocks may be joined with horizontal lines, semi-transparent
### blocks or no joins at all 

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Create each "feature" as a set of glyphs: blocks plus joins
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

  my $colour      = $feature->{'colour'};
  my $join_colour = $feature->{'join_colour'} || $feature->{'bordercolour'} || $colour;

  my $track_config  = $self->track_config;
  my $join          = $track_config->get('no_join') ? 0 : 1;

  my %defaults = (
                  y            => $position->{'y'},
                  height       => $position->{'height'},
                  strand       => $feature->{'strand'},
                  href         => $feature->{'href'},
                  title        => $feature->{'title'},
                  absolutey    => 1,
                );

  my $image_width = $position->{'image_width'};
  my %previous;

  foreach (@$structure) {

    my $last_element = 0;

    ## Join this block to the previous one
    if ($join && keys %previous) {
      my %params        = %defaults;
      $params{'join_colour'}  = $join_colour;

      my $start         = $previous{'x'} + $previous{'width'};
      $params{'x'}      = $start;
      my $end           = $_->{'start'};
      my $width         = $end - $start;
      if ($end > $image_width) {
        $width          = $image_width - $start;
        $last_element   = 1;
      }
      $params{'width'}        = $width;

      $self->draw_join(%params);      
    }
    last if $last_element;

    ## Now draw the next chunk of structure
    my %params = %defaults;

    my $start = $_->{'start'};
    my $end   = $_->{'end'};
    $params{'x'}      = $start;
    $params{'width'}  = $end - $start;

    ## Only draw blocks that appear on the image!
    if ($end < 0 || $start > $image_width) {
      ## Pretend we drew a block at the start of the image
      $params{'x'} = $end < 0 ? 0 : $image_width; 
    }
    else {
      $params{'colour'}     = $colour;
      $params{'structure'}  = $_;
      $self->draw_block(%params);
    }
    $current_x += $width;
    %previous = %params;
  }
}

sub draw_join {
  my ($self, %params) = @_;
  my $alpha = $self->track_config->get('alpha');

  if ($alpha) {
    $params{'colour'} = $params{'join_colour'};
    $params{'alpha'}  = $alpha;
  }
  else {
    $params{'bordercolour'} = $params{'join_colour'};
  }
  delete $params{'join_colour'};
  push @{$self->glyphs}, $self->Rect(\%params);
}

sub draw_block {
  my ($self, %params) = @_;
  push @{$self->glyphs}, $self->Rect(\%params);
}

1;
