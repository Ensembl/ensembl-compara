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

use List::Util qw(min max);

use parent qw(EnsEMBL::Draw::GlyphSet);

use EnsEMBL::Draw::Style::Feature::Transcript;

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('show_labels', 1);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('depth', 20);
  $self->{'my_config'}->set('bumped', 1);

  my $data = $self->get_data;
  return unless scalar @{$data->[0]{'features'}||[]};

  my $config = $self->track_style_config;
  my $style  = EnsEMBL::Draw::Style::Feature::Transcript->new($config, $data);
  $self->push($style->create_glyphs);
}

sub get_data {
  my ($self)  = @_;
  my $slice       = $self->{'container'};
  my $slice_start = $slice->start;
  my $colour      = $self->my_colour('lrg_import');
  my $data        = [{'features' => []}];

  my $lrg_slices = $slice->project('lrg') || [];
  my $genes = [];
  my %seen_genes;

  foreach (@$lrg_slices) {
    my $lrg_slice = $_->to_Slice;
    if ($lrg_slice) {
      ## Dedupe, as one gene may span multiple projected slices
      foreach my $g (@{$lrg_slice->get_all_Genes('LRG_import')||[]}) {
        next if $seen_genes{$g->stable_id};
        $seen_genes{$g->stable_id} = 1;
        push @$genes, $g;
      }
    }
  }
  return $data unless scalar @$genes;

  foreach my $g (@$genes) {
    next if $g->strand != $self->strand;

    ## We don't really need the gene, as it's not rendered, so base
    ## the data returned around the set of transcripts
    my $transcripts = $g->get_all_Transcripts;
    foreach my $t (@$transcripts) {

      ## Project the transcript back onto the slice, so we can get the real coordinates
      my $projection  = $t->project_to_slice($slice);
      my $real_start  = $projection->[0][2]->start - $slice_start + 1;
      my $real_end    = $projection->[0][2]->end - $slice_start + 1;

      my $label;
      $label = '< ' if ($g->strand == -1);
      $label .= $t->stable_id;
      $label .= ' >' if ($g->strand == 1);

      my $t_coding_start  = $t->coding_region_start // -1e6;
      my $t_coding_end    = $t->coding_region_end // -1e6;
      my $offset          = $real_start - $t->start;
      my $structure       = [];

      foreach my $e (sort { $a->start <=> $b->start } @{$t->get_all_Exons}) {
        next unless defined $e;
        my ($start, $end) = ($e->start, $e->end); 
        my $ef = {
                  start => $start + $offset,
                  end   => $end + $offset,
                  };
        ## Drawing code always defines UTRs wrt the forward strand
        ## as that is how the glyphs are created
        my $coding_start = max($t_coding_start,$start);
        my $coding_end = min($t_coding_end,$end);
        if ($coding_start > $end || $coding_end < $start) {
          $ef->{'non_coding'} = 1;
        }
        else {
          if ($coding_start > $start) {
            $ef->{'utr_5'} = $coding_start + $offset;
          }
          if ($coding_end < $end) {
            $ef->{'utr_3'} = $coding_end + $offset;
          }
        }
        push @$structure, $ef;
      }

      my $tf = {
                start     => $real_start,
                end       => $real_end,
                colour    => $colour,
                label     => $label,
                href      => $self->href($g, $t),
                structure => $structure,
                };
      push @{$data->[0]{'features'}}, $tf;
    }
  }

  return $data;
}

sub href {
  my ($self, $g, $t) = @_;
  my $href = {
              'type'    => 'Transcript',
              'action'  => 'LRG',
              'g'       => $g->stable_id,
              't'       => $t->stable_id,
  };
  return $self->_url($href);
}

1;
