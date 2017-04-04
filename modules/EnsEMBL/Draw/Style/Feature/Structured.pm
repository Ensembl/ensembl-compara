=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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
#  warn "\n\n>>> DRAWING FEATURE ".$feature->{'label'}; 

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
  my $join_colour = $feature->{'join_colour'};

  my $track_config  = $self->track_config;
  my $join          = $track_config->get('no_join') ? 0 : 1;

  ## Need to set y to 0 here, as a composite's components' y-coords are _added_ to this base y
  my $composite = $self->Composite({
                                      y       => 0,
                                      height  => $position->{'height'},
                                      title   => $feature->{'title'},
                                      href    => $feature->{'href'},
                                      class   => 'group',
                                  });

  my %defaults = (
                  y            => $position->{'y'},
                  height       => $position->{'height'},
                  strand       => $feature->{'strand'},
                  colour       => $colour,
                  absolutey    => 1,
                );

  my $image_width = $position->{'image_width'};
  my %previous;

  foreach (@$structure) {

    my $last_element = 0;

    ## Draw a join between this block and the previous one unless they're contiguous
    if ($join && keys %previous && ($_->{'start'} - $previous{'end'}) > 1) {
      my %params        = %defaults;
      $params{'colour'} = $join_colour unless $track_config->get('collapsed');

      my $start         = $previous{'x'} + $previous{'width'};
      $start            = 1 if $start < 1;
      $params{'x'}      = $start - 1;
      my $end           = $_->{'start'};
      my $width         = $end - $start + 1;
      if ($end > $image_width) {
        $width          = $image_width - $start + 1;
        $last_element   = 1;
      }
      $params{'width'}  = $width;
      $params{'href'}   = $feature->{'href'};

      $self->draw_join($composite, %params);      
    }
    last if $last_element;

    ## Now draw the next chunk of structure
    my %params = %defaults;

    my $start = $_->{'start'};
    $start = 1 if $start < 1;
    my $end   = $_->{'end'};
    $params{'x'}      = $start - 1;
    $params{'width'}  = $end - $start + 1;
    $params{'href'}   = $_->{'href'} || $feature->{'href'};

    ## Only draw blocks that appear on the image!
    if ($end < 0 || $start > $image_width) {
      ## Pretend we drew a block at the start of the image
      $params{'x'} = $end < 0 ? 0 : $image_width; 
    }
    else {
      $params{'colour'}     = $colour;
      $params{'structure'}  = $_;
      $self->draw_block($composite, %params);
    }
    $current_x += $width;
    %previous = %params;
  }

  ## Add any 'bridges', i.e. extra glyphs to join two corresponding features
  foreach (@{$feature->{'bridges'}||[]}) {
    $self->draw_bridge($composite ,$_);
  } 

  push @{$self->glyphs}, $composite;
}

sub draw_join {
  my ($self, $composite, %params) = @_;
  my $alpha = $self->track_config->get('alpha');

  if ($alpha) {
    $params{'alpha'}  = $alpha;
  }
  else {
    $params{'bordercolour'} = $params{'colour'};
    delete $params{'colour'};
  }
  $composite->push($self->Rect(\%params));
}

sub draw_block {
  my ($self, $composite, %params) = @_;
  $composite->push($self->Rect(\%params));
}

sub draw_bridge {
  ## Set up a "join tag" to display mapping between features, e.g. homologues
  ## This will actually be rendered into a glyph later, when all the glyphsets are drawn
  my ($self, $composite, $bridge) = @_;
  $self->add_bridge($composite, $bridge->{'key'}, 0.5, 0.5, $bridge->{'colour'}, 'line', 1000);
}

1;
