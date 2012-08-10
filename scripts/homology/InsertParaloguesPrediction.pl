#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $usage = "
$0 options input_data_file
  [--help]                      this menu
   --species string             (e.g. human) one of the species database (GenomeDB name)
  [--method_link_type string]   the source name of the homology to be loaded (default is ENSEMBL_PARALOGUES);
  [--description string]        the description of the homology to be loaded (default is YoungParalogues)

The format of the input file is 22 tab-separated columns. One homology per line.
dn ds n s lnl threshold_on_ds \
gene_stable_id1 translation_stable_id1 cigar_line1 \
cigar_start1 cigar_end1 perc_cov1 perc_id1 perc_pos1 \
gene_stable_id2 translation_stable_id2 cigar_line2 \
cigar_start2 cigar_end2 perc_cov2 perc_id2 perc_pos2

e.g.

0.0409  0.0806  1320.8  419.2   -2725.175299    0.5333  \
ENSG00000184263 ENSP00000328059 47MD159MD243M39D37M2D4MD90M     \
1       580     100.00  92.24   94.48   \
ENSG00000131263 ENSP00000253571 624M        \
1       624     92.95   85.74   87.82

cigar_start and cigar_end are NOT SUPPORTED any more

\n";

my $help = 0;
my $method_link_type = "ENSEMBL_PARALOGUES";
my $description = "YoungParalogues";
my $species;
my $compara_url;

GetOptions('help' => \$help,
           'species=s' => \$species,
           'method_link_type=s' => \$method_link_type,
           'description=s' => \$description,
           'compara_url=s' => \$compara_url);

$! = 1;

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url => $compara_url);
my $ha = $compara_dba->get_HomologyAdaptor;
my $ma = $compara_dba->get_MemberAdaptor;
my $gdba = $compara_dba->get_GenomeDBAdaptor;
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

my $gdb = $gdba->fetch_by_name_assembly($species);

my $idx = 1;

my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
    -method => $compara_dba->get_MethodAdaptor->fetch_by_type($method_link_type),
    -species_set_obj => $compara_dba->get_SpeciesSetAdaptor->fetch_by_GenomeDBs([$gdb]),
);
$mlssa->store($mlss);

while (<>) {
  chomp;
  my ($dn, $ds, $n, $s, $lnl, $threshold_on_ds,
      $gene_stable_id1, $translation_stable_id1, $cigar_line1,
      $cigar_start1, $cigar_end1, $perc_cov1, $perc_id1, $perc_pos1,
      $gene_stable_id2, $translation_stable_id2, $cigar_line2,
      $cigar_start2, $cigar_end2, $perc_cov2, $perc_id2, $perc_pos2) = split /\t/;

  my $gene_member1 = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_stable_id1);
  unless (defined  $gene_member1) {
    print STDERR "$gene_stable_id1 not in db\n";
    next;
  }
  my $peptide_member1 = $ma->fetch_by_source_stable_id("ENSEMBLPEP",$translation_stable_id1);
  unless (defined  $peptide_member1) {
    print STDERR "$translation_stable_id1 not in db\n";
    next;
  }
  make_alignedmember($peptide_member1, $cigar_line1,$perc_cov1,$perc_id1,$perc_pos1);

  my $gene_member2 = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_stable_id2);
  unless (defined  $gene_member2) {
    print STDERR "$gene_stable_id2 not in db\n";
    next;
  }
  my $peptide_member2 = $ma->fetch_by_source_stable_id("ENSEMBLPEP",$translation_stable_id2);
  unless (defined  $peptide_member2) {
    print STDERR "$translation_stable_id2 not in db\n";
    next;
  }
  make_alignedmember($peptide_member2, $cigar_line2,$perc_cov2,$perc_id2,$perc_pos2);

  my $homology = new Bio::EnsEMBL::Compara::Homology;
  my $stable_id = $gene_member1->taxon_id . "_" . $gene_member2->taxon_id . "_";
  $stable_id .= sprintf ("%011.0d",$idx);
  $idx++;
  $homology->method_link_species_set($mlss);
  $homology->stable_id($stable_id);
  $homology->description($description);
  $homology->dn($dn,0);
  $homology->ds($ds,0);
  $homology->n($n);
  $homology->s($s);
  $homology->lnl($lnl);
  $homology->threshold_on_ds($threshold_on_ds);
  $homology->add_Member($peptide_member1);
  $homology->add_Member($peptide_member2);
  print STDERR $homology->stable_id," ready to load\n";
  $ha->store($homology);
  if (defined $homology->n) {
    $ha->update_genetic_distance($homology);
  }
}


sub make_alignedmember {
  my ($peptide_member, $cigar_line, $perc_cov,$perc_id,$perc_pos) = @_;

  bless $peptide_member, 'Bio::EnsEMBL::Compara::AlignedMember';

  $peptide_member->cigar_line($cigar_line);
  $peptide_member->perc_cov($perc_cov);
  $peptide_member->perc_id($perc_id);
  $peptide_member->perc_pos($perc_pos);

}
