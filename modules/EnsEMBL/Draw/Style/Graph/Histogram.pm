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

  my $use_points  = $c->{'graph_type'} && $c->{'graph_type'} eq 'points';
  my $same_strand = $c->{'same_strand'};

  foreach my $f (@$features) {

    if (defined($f->{'strand'})) {
      if ($f->{'strand'} == 0) {
        ## Unstranded data goes on the reverse strand
        next if $same_strand && $same_strand == 1;
      }
      else {
      ## Skip unless feature is on this strand
      next if defined($same_strand) && $f->{'strand'} != $same_strand;
      }
    }

    my $start   = $f->{'start'};
    my $end     = $f->{'end'};
    my $score   = $f->{'score'};
    my $href    = $f->{'href'};
    my $height  = int(($score - $c->{'line_score'}) * $c->{'pix_per_score'});
    $height     = $c->{'cutoff'} if $c->{'cutoff'} && $height > $c->{'cutoff'};
    my $title   = $c->{'score_format'} ? sprintf($c->{'score_format'}, $score) : $score;

    my $params = {
                  y         => $c->{'line_px'} - max($height, 0),
                  height    => $use_points ? 0 : abs $height,
                  x         => $start - 1,
                  width     => $end - $start + 1,
                  colour    => $self->set_colour($c, $f) || $c->{'colour'},
                  alpha     => $self->track_config->get('use_alpha') ? 0.5 : 0,
                  title     => $self->track_config->get('no_titles') ? undef : $title,
                  href      => $href,
                  %{$c->{'absolute_xy'}},
                };
    #use Data::Dumper; warn Dumper($params);
    push @{$self->glyphs}, $self->Rect($params);
  }
}

1;
