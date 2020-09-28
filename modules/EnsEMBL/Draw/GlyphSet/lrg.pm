=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::lrg;

## Draws LRGs on Region in Detail, because they're not normal transcripts, therefore
##  the main transcript drawing code (and associated precache) doesn't work for them

use strict;

use parent qw(EnsEMBL::Draw::GlyphSet);

use EnsEMBL::Draw::Style::Feature::Structured;

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('show_labels', 1);
  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('depth', 20);

  my $data = $self->get_data;
  return unless scalar @{$data->[0]{'features'}||[]};

  my $config = $self->track_style_config;
  my $style  = EnsEMBL::Draw::Style::Feature::Structured->new($config, $data);
  $self->push($style->create_glyphs);
}

sub get_data {
  my ($self)  = @_;
  my $slice   = $self->{'container'};
  my $data    = [{'features' => []}];

  my $lrg_slices = $slice->project('lrg');
  if ($lrg_slices->[0]) {
    my $lrg_slice = $lrg_slices->[0]->to_Slice;
    my $genes     = $lrg_slice->get_all_Genes('LRG_import');
    my $colour  = $self->my_colour('lrg_import');

    foreach my $g (@$genes) {
      next if $g->strand != $self->strand;
      ## We don't really need the gene, as it's not rendered
      my $transcripts = $g->get_all_Transcripts;
      foreach my $t (@$transcripts) {
        my ($start, $end);
        warn sprintf '>>> TRANSCRIPT IS AT %s - %s', $t->start, $t->end; 
      #my $pg = $g->project_to_slice($slice);
      #foreach (@$pg) {
      #  warn "... PROJECTION @$_";
      #  $g_start  = $_->[0] unless $g_start;
      #  $g_end    = $_->[1];
      #}
        my $tf = {
                  start   => $t->start,
                  end     => $t->end,
                  colour  => $colour,
                  label   => $t->stable_id,
                  };
        push @{$data->[0]{'features'}}, $tf;
      }
    }
  }

  use Data::Dumper;
  $Data::Dumper::Sortkeys = 1;
  warn Dumper($data->[0]{'features'});

  return $data;
}



1;
