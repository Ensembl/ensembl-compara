#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Attribute;

$! = 1;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => "ia64e",
                                                     -port => 3306,
                                                     -user => "ensadmin",
                                                     -pass => "ensembl",
                                                     -dbname => "ensembl_compara_23_1");

my $ha = $db->get_HomologyAdaptor;
my $ma = $db->get_MemberAdaptor;

my $idx = 1;

while (<>) {
  chomp;
  my ($dn, $ds, $n, $s, $lnl, $threshold_on_ds,
      $gene_stable_id1, $translation_stable_id1, $cigar_line1,
      $cigar_start1, $cigar_end1, $perc_cov1, $perc_id1, $perc_pos1,
      $gene_stable_id2, $translation_stable_id2, $cigar_line2,
      $cigar_start2, $cigar_end2, $perc_cov2, $perc_id2, $perc_pos2) = split /\t/;

  my $gene_member1 = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_stable_id1);
  unless (defined  $gene_member1) {
    print "$gene_stable_id1 not in db\n";
  }
  my $peptide_member1 = $ma->fetch_by_source_stable_id("ENSEMBLPEP",$translation_stable_id1);
  unless (defined  $peptide_member1) {
    print "$translation_stable_id1 not in db\n";
  }
  my $attribute1 = return_attribute($peptide_member1, $cigar_line1, $cigar_start1, $cigar_end1,$perc_cov1,$perc_id1,$perc_pos1);

  my $gene_member2 = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_stable_id2);
  unless (defined  $gene_member2) {
    print "$gene_stable_id2 not in db\n";
  }
  my $peptide_member2 = $ma->fetch_by_source_stable_id("ENSEMBLPEP",$translation_stable_id2);
  unless (defined  $peptide_member2) {
    print "$translation_stable_id2 not in db\n";
  }
  my $attribute2 = return_attribute($peptide_member2, $cigar_line2, $cigar_start2, $cigar_end2,$perc_cov2,$perc_id2,$perc_pos2);

  my $homology = new Bio::EnsEMBL::Compara::Homology;
  my $stable_id = $gene_member1->taxon_id . "_" . $gene_member2->taxon_id . "_";
  $stable_id .= sprintf ("%011.0d",$idx);
  $idx++;
  $homology->stable_id($stable_id);
  $homology->source_name("ENSEMBL_PARALOGUES");
  # BestReciprocalHit
  # ReciprocalHitbasedonSynteny
  $homology->description("YoungParalogues");
  $homology->dn(0,$dn);
  $homology->ds(0,$ds);
  $homology->n($n);
  $homology->s($s);
  $homology->lnl($lnl);
  $homology->threshold_on_ds($threshold_on_ds);
  $homology->add_Member_Attribute([$gene_member1, $attribute1]);
  $homology->add_Member_Attribute([$gene_member2, $attribute2]);
  print $homology->stable_id," ready to load\n";
  $ha->store($homology);
}


sub return_attribute {
  my ($peptide_member, $cigar_line, $cigar_start, $cigar_end,$perc_cov,$perc_id,$perc_pos) = @_;
  
  my $attribute = Bio::EnsEMBL::Compara::Attribute->new_fast
      ({'peptide_member_id' => $peptide_member->dbID});

  $attribute->cigar_line($cigar_line);
  $attribute->cigar_start($cigar_start);
  $attribute->cigar_end($cigar_end);
  $attribute->perc_cov($perc_cov);
  $attribute->perc_id($perc_id);
  $attribute->perc_pos($perc_pos);

  return $attribute;
}
