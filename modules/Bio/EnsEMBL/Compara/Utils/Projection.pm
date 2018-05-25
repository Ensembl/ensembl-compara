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

=head1 DESCRIPTION

This module has various methods to help with projecting stuff


=cut

package Bio::EnsEMBL::Compara::Utils::Projection;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);


=head2 project_Slice_to_reference_toplevel

  Arg[1]      : Bio::EnsEMBL::Slice $slice
  Example     : $object_name->project_Slice_to_reference_toplevel();
  Description : Project a Slice to top-level regions that we store as DnaFrags
  Returntype  : Arrayref of Bio::EnsEMBL::ProjectionSegment
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub project_Slice_to_reference_toplevel {
    my ($slice) = @_;

    # Test data
    #  - non-toplevel contig that is not assembled into toplevel                BX649553.6: 1,900-2,000
    #  - non-toplevel contig that is partly assembled into primary toplevel     AC090095.7: 21,000-22,000
    #  - non-toplevel contig that is fully assembled into primary toplevel      AC090095.7: 22,000-23,000
    #  - non-toplevel contig that is partly assembled into PAR toplevel         BX649553.6: 1,900-2,100
    #  - non-toplevel contig that is fully assembled into PAR toplevel          BX649553.6: 2,001-2,100
    #  - non-toplevel contig that is partly assembled into HAP toplevel         AC221020.3: 36,050-36,250
    #  - non-toplevel contig that is fully assembled into HAP toplevel          AC221020.3: 36,050-36,150
    #  - non-toplevel contig that is partly assembled into PATCH toplevel       AC270248.1: 79,700-79,800
    #  - non-toplevel contig that is fully assembled into PATCH toplevel        AC270248.1: 79,800-79,900
    #  - toplevel slice that is on the primary assembly (non PAR)               8: 32,295,386-32,299,282
    #  - toplevel slice that is fully on PAR (X)                                X: 1,450,394-1,550,394
    #  - toplevel slice that is fully on PAR (Y)                                Y: 1,286,355-1,386,355
    #  - toplevel slice that is overlapping PAR (Y)                             Y: 2,680,997-2,930,998
    #  - toplevel slice that is fully on HAP                                    CHR_HSCHR6_MHC_COX_CTG1: 30,889,254-30,926,255
    #  - toplevel slice that is overlapping a HAP                               CHR_HSCHR6_MHC_COX_CTG1: 28,510,040-28,510,182
    #  - toplevel slice that is fully on PATCH                                  CHR_HG2072_PATCH: 82,385,389-82,386,104
    #  - toplevel slice that is overlapping a PATCH                             CHR_HG2072_PATCH: 82,385,389-82,386,204

    assert_ref($slice, 'Bio::EnsEMBL::Slice', 'slice');

    my $projection_segments;

    if ($slice->is_toplevel) {
        # The slice is already top-level, like the dnafrags, but may be on
        # a non-reference region. fetch_normalized_slice_projection will
        # split and project the slice to the reference regions where
        # possible.
        # When the slice is not fully on the assembly exception, the
        # 'filter_projections' flag will make
        # fetch_normalized_slice_projection return a dummy projection
        # segment onto itself
        $projection_segments = $slice->adaptor->fetch_normalized_slice_projection($slice, 'filter_projections');

    } else {
        # The slice is not top-level. Let's project it up
        $projection_segments = $slice->project('toplevel');
        # By the way, when the projection is not possible (none of $slice is included
        # in a toplevel), $projection_segments will contain a copy of the
        # original slice. This is fine and gives us a chance to fetch some
        # alignments etc, if we have computed them on this region.
    }

    return $projection_segments;
}


=head2 project_Slice_to_target_genome

    Arg[1]      : Bio::EnsEMBL::Slice $slice
    Arg[2]      : Bio::EnsEMBL::COMPARA::MethodLinkSpeciesSet $mlss
    Arg[3]      : (Optional) the name of the target species if the mlss is for a multiple genome alignment
    Example     : $object_name->project_Slice_to_target_genome();
    Description : This script takes as input the desired coordinates on the genome of a given species and uses the genomic aligns block object and the mapper object to map those coordinates
                    to their corresponding aligned coordinates on a target species genome.
    Returntype  : Arrayref of paired hash objects each pair respresenting a one to one mapping of the aligned coordinates on both source and target species
    Exceptions  : none
    Caller      : general
    Status      : Stable
=cut

sub project_Slice_to_target_genome {
    my ($slice, $mlss, $target_sp) = @_;

    if ($mlss->method()->class ne 'GenomicAlignBlock.pairwise_alignment' && $target_sp eq '') {
    die "you have given an mlss for a multiple WGA but have forgotten to give your preferred target species";
    }

    my $gblock_adap = $mlss->adaptor->db->get_GenomicAlignBlockAdaptor;
    my $gdb_adap = $mlss->adaptor->db->get_GenomeDBAdaptor;

    my $all_genomic_align_blocks = $gblock_adap->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
    my $ref_sp = $gdb_adap->fetch_by_Slice($slice)->name;

    my ($slice_start,$slice_end,$slice_strand) = ($slice->start, $slice->end, $slice->strand);
    my ($linked, @overall_linked);

    foreach my $gab (@{$all_genomic_align_blocks}) {
        $linked = $gab->get_mapper_coordinates($slice_start,$slice_end,$ref_sp, $target_sp);
        push (@overall_linked, @$linked);
    }

    return \@overall_linked; 

}
1;
