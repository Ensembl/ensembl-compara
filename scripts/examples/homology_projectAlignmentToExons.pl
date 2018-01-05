#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script maps the exons of pairs of orthologues onto their
# peptide alignments
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor ("Homo sapiens", "core", "Gene");
my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor ("Multi", "compara", "GeneMember");
my $homology_adaptor = Bio::EnsEMBL::Registry->get_adaptor ("Multi", "compara", "Homology");

my $genes = $human_gene_adaptor-> fetch_all_by_external_name('BRCA2');

my $gene = shift @$genes; # We assume we have only one gene

my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
my @mouse_homologies = @{$homology_adaptor->fetch_all_by_Member($member, -TARGET_SPECIES => 'Mus_musculus', -METHOD_LINK_TYPE => 'ENSEMBL_ORTHOLOGUES')};
my @rat_homologies = @{$homology_adaptor->fetch_all_by_Member($member, -TARGET_SPECIES => 'Rattus_norvegicus', -METHOD_LINK_TYPE => 'ENSEMBL_ORTHOLOGUES')};

my $aligned_member = $member->get_canonical_SeqMember;

sub print_transcript {
  my ($transcript, $cdna_simple_align) = @_;

    # The Ensembl phase convention can be thought of as
    # "the number of bases of the first codon which are
    # on the previous exon".  It is therefore 0, 1 or 2
    # (or -1 if the exon is non-coding).  In ascii art,
    # with alternate codons represented by B<###> and
    # B<+++>:

    #        Previous Exon   Intron   This Exon
    #     ...-------------            -------------...

    #     5'                    Phase                3'
    #     ...#+++###+++###          0 +++###+++###+...
    #     ...+++###+++###+          1 ++###+++###++...
    #     ...++###+++###++          2 +###+++###+++...

  my @this_exons = @{$transcript->get_all_translateable_Exons};
  my $exon_num = scalar(@this_exons);
  my $this_exon = 0;
  my $merged_cdna_exon_length = 0;
  my $utr = $transcript->five_prime_utr;
  my $utr_length = 0;
  eval {$utr_length = length($utr->seq);};
  foreach my $exon (@this_exons) {
    $this_exon++;
    $merged_cdna_exon_length += $exon->end - $exon->start;
    my $exon_stable_id = $exon->stable_id;
    my $coding_region_start = $exon->coding_region_start($transcript);
    my $coding_region_end = $exon->coding_region_end($transcript);
    my $cdna_coding_start = $exon->cdna_coding_start($transcript) - $utr_length;
    my $cdna_coding_end = $exon->cdna_coding_end($transcript) - $utr_length;
    my $display_id = $transcript->translation->stable_id;
    my $aln_pos_start;
    if (($cdna_coding_end - $cdna_coding_start <= 3) && ($this_exon == $exon_num)) {
      print "$exon_stable_id,$cdna_coding_start,$coding_region_start,na,$cdna_coding_end,$coding_region_end,na\n";
      next;
    } else {
      $aln_pos_start = $cdna_simple_align->column_from_residue_number($display_id, $cdna_coding_start);
    }
    my $aln_pos_end;
    if ($this_exon == $exon_num) {
      # We dont have the stop codons in the alignment, so give the previous codon end
      $cdna_coding_end -= 3;
      $coding_region_end -= 3;
    }
    $aln_pos_end  = $cdna_simple_align->column_from_residue_number($display_id, $cdna_coding_end);
    print "$exon_stable_id,$cdna_coding_start,$coding_region_start,$aln_pos_start,$cdna_coding_end,$coding_region_end,$aln_pos_end\n";
  }

# From bioperl's Bio::SimpleAlign 

#  Title   : column_from_residue_number
#  Usage   : $col = $ali->column_from_residue_number( $seqname, $resnumber)
#  Function: This function gives the position in the alignment
#            (i.e. column number) of the given residue number in the
#            sequence with the given name. For example, for the
#            alignment

#   	     Seq1/91-97 AC..DEF.GH
#   	     Seq2/24-30 ACGG.RTY..
#   	     Seq3/43-51 AC.DDEFGHI

#            column_from_residue_number( "Seq1", 94 ) returns 5.
#            column_from_residue_number( "Seq2", 25 ) returns 2.
#            column_from_residue_number( "Seq3", 50 ) returns 9.

#            An exception is thrown if the residue number would lie
#            outside the length of the aligment
#            (e.g. column_from_residue_number( "Seq2", 22 )

# 	  Note: If the the parent sequence is represented by more than
# 	  one alignment sequence and the residue number is present in
# 	  them, this method finds only the first one.

#  Returns : A column number for the position in the alignment of the
#            given residue in the given sequence (1 = first column)
#  Args    : A sequence id/name (not a name/start-end)
#            A residue number in the whole sequence (not just that
#            segment of it in the alignment)

}


foreach my $homology (@mouse_homologies, @rat_homologies) {
  print "\n", $homology->toString();
  my $cdna_simple_align = $homology->get_SimpleAlign(-seq_type => 'cds');
  my ($gene1,$gene2) = @{$homology->gene_list};
  my $temp;
  unless ($gene1->stable_id =~ /ENSG0/) {
    $temp = $gene1;
    $gene1 = $gene2;
    $gene2 = $temp;
  }
  my $member2 = $gene_member_adaptor->fetch_by_stable_id($gene2->stable_id);

  print_transcript($member->get_canonical_SeqMember->get_Transcript, $cdna_simple_align);
  print_transcript($member2->get_canonical_SeqMember->get_Transcript, $cdna_simple_align);

}


