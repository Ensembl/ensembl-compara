#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Attribute;

my $usage = "
$0 options input_data_file
  [--help]                      this menu
   --dbname string              (e.g. compara23) one of the compara database Bio::EnsEMBL::Registry aliases
  [--source_name string]        the source name of the homology to be loaded (default is ENSEMBL_PARALOGUES);
  [--description string]        the description of the homology to be loaded (default is YoungParalogues)
  [--reg_conf filepath]         the Bio::EnsEMBL::Registry configuration file. If none given, 
                                the one set in ENSEMBL_REGISTRY will be used if defined, if not
                                ~/.ensembl_init will be used.
\n";

my $help = 0;
my $source_name = "ENSEMBL_PARALOGUES";
my $description = "YoungParalogues";
my ($dbname,$reg_conf);

GetOptions('help' => \$help,
           'dbname=s' => \$dbname,
           'source_name=s' => \$source_name,
           'description=s' => \$description,
           'reg_conf=s' => \$reg_conf);

$! = 1;

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $ha = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','Homology');
my $ma = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','Member');

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
  $homology->source_name($source_name);
  $homology->description($description);
  $homology->dn($dn,0);
  $homology->ds($ds,0);
  $homology->n($n);
  $homology->s($s);
  $homology->lnl($lnl);
  $homology->threshold_on_ds($threshold_on_ds);
  $homology->add_Member_Attribute([$gene_member1, $attribute1]);
  $homology->add_Member_Attribute([$gene_member2, $attribute2]);
  print $homology->stable_id," ready to load\n";
  $ha->store($homology);
  $ha->update_genetic_distance($homology);
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
