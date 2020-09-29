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
  my $slice   = $self->{'container'};
  my $data    = [{'features' => []}];

  my $lrg_slices = $slice->project('lrg');
  if ($lrg_slices->[0]) {
    my $lrg_slice = $lrg_slices->[0]->to_Slice;
    my $genes     = $lrg_slice->get_all_Genes('LRG_import');
    my $colour  = $self->my_colour('lrg_import');

    foreach my $g (@$genes) {
      next if $g->strand != $self->strand;
      ## We don't really need the gene, as it's not rendered, so base
      ## the data returned around the set of transcripts
      my $transcripts = $g->get_all_Transcripts;
      foreach my $t (@$transcripts) {

        my $label;
        $label = '< ' if ($g->strand == -1);
        $label .= $t->stable_id;
        $label .= ' >' if ($g->strand == 1);

        my $structure = [];
        my $t_coding_start = $t->coding_region_start // -1e6;
        my $t_coding_end = $t->coding_region_end // -1e6;
        foreach my $e (sort { $a->start <=> $b->start } @{$t->get_all_Exons}) {
          next unless defined $e;
          my ($start, $end) = ($e->start, $e->end); 
          my $ef = {
                    start => $start,
                    end   => $end,
                    };
          my $coding_start = max($t_coding_start,$start);
          my $coding_end = min($t_coding_end,$end);
          if ($coding_start > $end || $coding_end < $start) {
            $ef->{'non_coding'} = 1;
          }
          else {
            if ($g->strand == 1) {
              if ($coding_start < $end) {
                $ef->{'utr_5'} = $coding_start;
              }
              if ($coding_end > $start) {
                $ef->{'utr_3'} = $coding_end;
              }
            }
            else {
              if ($coding_start < $end) {
                $ef->{'utr_3'} = $coding_start;
              }
              if ($coding_end > $start) {
                $ef->{'utr_5'} = $coding_end;
              }
            }
          }
          push @$structure, $ef;
        }

        my $tf = {
                  start     => $t->start,
                  end       => $t->end,
                  colour    => $colour,
                  label     => $label,
                  href      => $self->href($g, $t),
                  structure => $structure,
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
