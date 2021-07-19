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

### Draws a generic bar chart as a series of discrete rectangles
### N.B. for continuous (binned) data, the Histogram style is
### a much more efficient way to draw the glyphs

package EnsEMBL::Draw::Style::Graph::Bar;

use List::Util qw(min max);

use parent qw(EnsEMBL::Draw::Style::Graph);

sub draw_wiggle {
  my ($self, $c, $features) = @_;
  return unless scalar(@$features);

  my $use_points  = $c->{'graph_type'} && $c->{'graph_type'} eq 'points';

  ## How wide is each bar, in pixels? (needed for label overlay)
  my $bar_width   = $self->image_config->container_width * $self->{'pix_per_bp'} / scalar(@$features);

  my $plain_x = 0;

  foreach my $_f (@$features) {

    my $f;

    if (ref $_f eq 'HASH') {
      $f = $_f;
    } else {
      # Plain old value
      $f = {
        start => $plain_x,
        end   => $plain_x + $c->{'unit'},
        score => $_f
      };
      $plain_x   += $c->{'unit'};
    }

    my $start   = $f->{'start'};
    my $end     = $f->{'end'};
    my $score   = $f->{'score'};
    if (defined($c->{'cutoff_max'}) && $score > $c->{'cutoff_max'}) {
      $score = $c->{'cutoff_max'};
    }
    elsif (defined($c->{'cutoff_min'}) && $score < $c->{'cutoff_min'}) {
      $score = $c->{'cutoff_min'};
    }
    my $href    = $f->{'href'};
    my $height  = int(($score - $c->{'line_score'}) * $c->{'pix_per_score'});
    my $title   = $f->{'title'};
    unless ($title) {
      $title = $c->{'score_format'} ? sprintf($c->{'score_format'}, $score) : $score;
    }
    my $x     = $start - 1;
    $x        = 0 if $x < 0;
    my $y     = $c->{'line_px'} - max($height, 0);
    my $width = $end - $start + 1;

    my $params = {
                  x         => $x,
                  y         => $y, 
                  width     => $width,
                  height    => $use_points ? 0 : abs $height,
                  colour    => $self->set_colour($c, $f) || $c->{'colour'},
                  alpha     => $self->track_config->get('use_alpha') ? 0.5 : 0,
                  title     => $self->track_config->get('no_titles') ? undef : $title,
                  href      => $href,
                  %{$c->{'absolute_xy'}},
                };
    #warn Dumper($params);
    push @{$self->glyphs}, $self->Rect($params);

    ## Superimposed label - mainly for sequence
    if ($self->track_config->get('overlay_label') && $f->{'label'}) {

      ## Do we have space to draw the label?
      my $text_info   = $self->get_text_info($feature->{'label'});

      if ($text_info->{'width'} < $bar_width) {
        ## Centre the text at the base of the bar
        $x += (($bar_width - $text_info->{'width'}) / $self->{'pix_per_bp'}) / 2;
        $y = $c->{'line_px'} - $self->{'font_size'} - 2;
        my $text_params = {
                            x         => $x,
                            y         => $y,
                            height    => $self->{'font_size'},
                            text      => $f->{'label'},
                            font      => $self->{'font_name'},
                            ptsize    => $self->{'font_size'},
                            colour    => $f->{'label_colour'} || 'black', 
                            %{$c->{'absolute_xy'}},
                          };
        #warn ">>> TEXT PARAMS ".Dumper($text_params);
        push @{$self->glyphs}, $self->Text($text_params);
      }
    }
  }
}

1;
