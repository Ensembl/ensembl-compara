#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
    (-host=>"ensembldb.ensembl.org", 
     -user=>"anonymous",
     -db_version=>'58');

print STDERR "This script was only tested with version 47\n" if (Bio::EnsEMBL::Registry->software_version ne '47');
# Bio::EnsEMBL::Registry->no_version_check(1);
my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "Homology");
my $proteintree_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
    ("Compara", "compara", "ProteinTree");

my $genes = $human_gene_adaptor->
   fetch_all_by_external_name('BRCA2');

my $gene = shift @$genes; # We assume we have only one gene

my $member = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
my @mouse_homologies = @{$homology_adaptor->fetch_all_by_Member_paired_species($member, "Mus_musculus",['ENSEMBL_ORTHOLOGUES'])};
my @rat_homologies = @{$homology_adaptor->fetch_all_by_Member_paired_species($member, "Rattus norvegicus",['ENSEMBL_ORTHOLOGUES'])};

my $aligned_member = $proteintree_adaptor->
  fetch_AlignedMember_by_member_id_root_id
  ($member->get_canonical_peptide_Member->member_id);

foreach my $homology (@mouse_homologies,@rat_homologies) {
  print "\n";
  $homology->print_homology;
  my $cdna_simple_align = $homology->get_SimpleAlign('cdna');
  my ($gene1,$gene2) = @{$homology->gene_list};
  my $temp;
  unless ($gene1->stable_id =~ /ENSG0/) {
    $temp = $gene1;
    $gene1 = $gene2;
    $gene2 = $temp;
  }
  my $member2 = $member_adaptor->
  fetch_by_source_stable_id("ENSEMBLGENE",$gene2->stable_id);
  my $aligned_member2 = $proteintree_adaptor->fetch_AlignedMember_by_member_id_root_id
  ($member2->get_canonical_peptide_Member->member_id);

  my $transcript = $aligned_member->transcript;
  my $transcript_stable_id = $transcript->stable_id;


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
  my $merged_exons_dna_simple_align = new Bio::SimpleAlign;
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

  my $transcript2 = $aligned_member2->transcript;
  my $transcript_stable_id2 = $transcript2->stable_id;
  my @this_exons2 = @{$transcript2->get_all_translateable_Exons};
  #          my $accum_start = 1;
  my $exon_num2 = scalar(@this_exons2);
  my $this_exon2 = 0;
  my $merged_cdna_exon_length2 = 0;
  #my $phase_this_exon = 0;
  my $merged_exons_dna_simple_align2 = new Bio::SimpleAlign;
  my $utr2 = $transcript2->five_prime_utr;
  my $utr_length2 = 0;
  eval {$utr_length2 = length($utr2->seq);};
  foreach my $exon2 (@this_exons2) {
    $this_exon2++;
    $merged_cdna_exon_length2 += $exon2->end - $exon2->start;
    my $exon_stable_id2 = $exon2->stable_id;
    my $coding_region_start2 = $exon2->coding_region_start($transcript2);
    my $coding_region_end2 = $exon2->coding_region_end($transcript2);
    my $cdna_coding_start2 = $exon2->cdna_coding_start($transcript2) - $utr_length2;
    my $cdna_coding_end2 = $exon2->cdna_coding_end($transcript2) - $utr_length2;
    my $display_id2 = $transcript2->translation->stable_id;
    my $aln_pos_start2;
    if (($cdna_coding_end2 - $cdna_coding_start2 <= 3) && ($this_exon2 == $exon_num2)) {
      print "$exon_stable_id2,$cdna_coding_start2,$coding_region_start2,na,$cdna_coding_end2,$coding_region_end2,na\n";
      next;
    } else {
      $aln_pos_start2 = $cdna_simple_align->column_from_residue_number($display_id2, $cdna_coding_start2);
    }
    my $aln_pos_end2;
    # print STDERR "[$this_exon2 / $exon_num2]\n";
    if ($this_exon2 == $exon_num2) {
      # We dont have the stop codons in the alignment, so give the previous codon end
      $cdna_coding_end2 -= 3;
      $coding_region_end2 -= 3;
      #print STDERR "$exon_stable_id2,$cdna_coding_start2,$coding_region_start2,$aln_pos_start2,$cdna_coding_end2,$coding_region_end2,-----\n";
    }
    $aln_pos_end2 = $cdna_simple_align->column_from_residue_number($display_id2, $cdna_coding_end2);
    print "$exon_stable_id2,$cdna_coding_start2,$coding_region_start2,$aln_pos_start2,$cdna_coding_end2,$coding_region_end2,$aln_pos_end2\n";
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
