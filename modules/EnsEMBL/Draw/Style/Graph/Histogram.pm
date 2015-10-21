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

package EnsEMBL::Draw::Style::Graph::Histogram;

use List::Util qw(min max);

use parent qw(EnsEMBL::Draw::Style::Graph);

sub draw_wiggle {
  my ($self, $c, $features) = @_;

  my $use_points    = $c->{'graph_type'} && $c->{'graph_type'} eq 'points';
  my $max_score     = $self->track_config->get('max_score');

  foreach my $f (@$features) {
    my $start   = $f->{'start'};
    my $end     = $f->{'end'};
    my $score   = $f->{'score'};
    my $href    = $f->{'href'};
    my $height  = ($score - $c->{'line_score'}) * $c->{'pix_per_score'};
    my $title   = sprintf('%.2f',$score);

    push @{$self->glyphs}, $self->Rect({
                              y         => $c->{'line_px'} - max($height, 0),
                              height    => $use_points ? 0 : abs $height,
                              x         => $start - 1,
                              width     => $end - $start + 1,
                              absolutey => 1,
                              colour    => $self->set_colour($c, $f) || $c->{'colour'},
                              alpha     => $self->track_config->get('use_alpha') ? 0.5 : 0,
                              title     => $self->track_config->get('no_titles') ? undef : $title,
                              href      => $href,
                           });
  }
}

1;
