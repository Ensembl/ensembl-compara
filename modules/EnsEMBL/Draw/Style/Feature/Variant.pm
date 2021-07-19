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

package EnsEMBL::Draw::Style::Feature::Variant;

=pod

Renders a variation track with variants drawn differently depending on what type they are. 

Whilst we try to keep biological information out of the lower-level drawing code as much 
as possible, the density of the variation tracks means we have to avoid looping through
the array of features. Hence this module decides how to draw each variant, rather than
the glyphset. 

=cut

use POSIX qw(floor);
use List::Util qw(min);

use parent qw(EnsEMBL::Draw::Style::Feature);

sub draw_feature {
### Draw a block with optional tags
  my ($self, $feature, $position) = @_;
  return unless $feature->{'colour'};

  if ($feature->{'type'}) {
    my $method = 'draw_'.$feature->{'type'};
    $self->$method($feature, $position) if $self->can($method); 
  }
  else {
    $self->SUPER::draw_feature($feature, $position);
  }

  ### Are we highlighting this feature? Default is no!
  if ($self->image_config->get_option('opt_highlight_feature') != 0) {

    my $var_id;
    my $variant = $self->image_config->core_object('variation');
    if ($variant) {
      $var_id = $variant->name;
    }

    if ($var_id && $var_id eq $feature->{'label'}) {
      ## Highlight just the feature (i.e. not including label), using a black border
      $position->{'highlight_height'} = $position->{'height'};
      $feature->{'highlight'}         = 'black';
    }
  }
}

sub draw_insertion {
### Draw a variant of type 'insertion'
### @param feature  - hashref describing the feature 
### @param position - hashref describing the position of the main feature
  my ($self, $feature, $position) = @_;

  my $composite = $self->Composite;
  foreach my $k (qw(title href class)) {
    $composite->{$k} = $feature->{$k} if exists $feature->{$k};
  }

  ## Scale the insertion so that it doesn't disappear when zoomed in!
  my $scale = 1;
  if ($self->{'pix_per_bp'} > 1) {
    $scale = floor($self->{'pix_per_bp'} / 5);
    ## Limit scaling to something sensible
    $scale = 1 if $scale < 1;
    $scale = 5 if $scale > 5;
  }

  ## Draw a narrow line to mark the insertion point
  my $x = $feature->{'start'};
  $x    = 1 if $x < 1;
  my $w = ($position->{'width'} / (2 * $self->{'pix_per_bp'})) * $scale;
  my $params = {
                  x         => $x - 1 - ($w / 2),
                  y         => $position->{'y'},
                  width     => $w,
                  height    => $position->{'height'},
                  colour    => $feature->{'colour'},
                  title     => $feature->{'title'},
                };
  $composite->push($self->Rect($params));

  ## invisible box to make inserts more clickable
  my $box_width = min(1, 16 / $self->{'pix_per_bp'});
  $params = {
              x         => $x - 1 - $box_width/2, 
              y         => $position->{'y'},
              width     => $box_width * $scale,
              height    => $position->{'height'} + 2,
            };
  $composite->push($self->Rect($params));

  ## Draw a triangle below the line to identify it as an insertion
  ## Note that we can't add the triangle to the composite, for Reasons
  my $y = $position->{'y'} + $position->{'height'};
  $params = {
              width         => (4 / $self->{'pix_per_bp'}) * $scale,
              height        => 3 * $scale,
              direction     => 'up',
              mid_point     => [ $x - 1, $y ],
              colour        => $feature->{'colour'},
              absolutey     => 1,
              no_rectangle  => 1,
              href          => $composite->{'href'},
             };
  my $triangle = $self->Triangle($params);

  ## OK, all done!
  push @{$self->glyphs}, $composite, $triangle;
}

sub draw_deletion {
### Create a glyph that's a filled rectangle with a superimposed triangle
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  ## First, create rectangle for deletion length 
  my $x = $feature->{'start'};
  $x    = 1 if $x < 1;
  my $params = {
                  x         => $x-1,
                  y         => $position->{'y'},
                  width     => $position->{'width'} + 1,
                  height    => $position->{'height'},
                  colour    => $feature->{'colour'},
                  href      => $feature->{'href'},
                  title     => $feature->{'title'},
                  absolutey => 1,
                };
  my $rectangle = $self->Rect($params);

  ## Now draw a triangle in the centre of the rectangle
  ## - but only if the feature is big enough!
  my $triangle;
  my $h = $position->{'height'} / 2;
  my $w = ($h * 4) / ($self->{'pix_per_bp'} * 3); 
  if ($w > 0 && ($position->{'width'} * $self->{'pix_per_bp'} > $w)) {  
    my $m = ($x + $feature->{'end'} - 1) / 2;
    my $y = $position->{'y'} + (($h + $position->{'height'}) / 2);
    my $colour = $self->make_contrasting($feature->{'colour'});
    $params = {
              width         => $w,
              height        => $h,
              direction     => 'down',
              mid_point     => [ $m, $y ],
              colour        => $colour,
              absolutey     => 1,
              no_rectangle  => 1,
              href          => $composite->{'href'},
             };
    $triangle = $self->Triangle($params);
  }

  push @{$self->glyphs}, $rectangle;
  push @{$self->glyphs}, $triangle if $triangle;
}

sub set_highlight {
}

1;
