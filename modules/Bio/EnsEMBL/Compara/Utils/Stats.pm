=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Stats

=head1 DESCRIPTION

Utility module for handling comparative analysis statistics.

=cut

package Bio::EnsEMBL::Compara::Utils::Stats;

use strict;
use warnings;

use base qw(Exporter);


our @EXPORT_OK = qw(
    get_coding_exon_regions
);


=head2 get_coding_exon_regions

  Arg [1]     : Bio::EnsEMBL::Slice $slice
  Example     : my $regions = get_coding_exon_regions($slice);
  Description : Retrieves the toplevel coordinates of coding
                exon regions of the given Slice object
  Returntype  : Arrayref of coordinate pairs of coding
                exon regions in the given Slice object

=cut

sub get_coding_exon_regions {
    my ($this_slice) = @_;

    my $regions = [];

    return $regions if (!$this_slice);

    my $all_coding_exons = [];
    my $all_genes = $this_slice->get_all_Genes_by_type("protein_coding");
    foreach my $this_gene (@$all_genes) {
        my $all_transcripts = $this_gene->get_all_Transcripts();
        foreach my $this_transcript (@$all_transcripts) {
            push(@$all_coding_exons, @{$this_transcript->get_all_translateable_Exons()});
        }
    }
    my $last_start = 0;
    my $last_end = -1;
    foreach my $this_exon (sort {$a->seq_region_start <=> $b->seq_region_start} @$all_coding_exons) {

        if ($last_end < $this_exon->seq_region_start) {
            if ($last_end > 0) {
                push(@$regions, [$last_start, $last_end]);
            }
            $last_end = $this_exon->seq_region_end;
            $last_start = $this_exon->seq_region_start;
        } elsif ($this_exon->seq_region_end > $last_end) {
            $last_end = $this_exon->seq_region_end;
        }
    }

    #Add final region
    push (@$regions, [$last_start, $last_end]);

    return $regions;
}


1;
