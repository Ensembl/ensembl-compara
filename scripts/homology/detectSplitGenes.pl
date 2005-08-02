#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
#use Bio::EnsEMBL::Compara::Homology;
#use Bio::EnsEMBL::Compara::Attribute;

my $help = 0;
my $usage = "usage\n";
my $method_link_type = "ENSEMBL_ORTHOLOGUES";
my ($informant_species, $targeted_species);
my ($dbname,$reg_conf);

my $informant_perc_cov = 20;
my $targeted_perc_cov = 70;
my $include_all = 0;

GetOptions('help' => \$help,
           'dbname=s' => \$dbname,
           'informant=s' => \$informant_species,
           'informant_perc_cov=s' => \$informant_perc_cov,
           'targeted=s' => \$targeted_species,
           'targeted_perc_cov=s' => \$targeted_perc_cov,
           'include_all' => \$include_all,
           'method_link_type=s' => \$method_link_type,
           'reg_conf=s' => \$reg_conf);

$! = 1;

#unless (scalar @ARGV) {
#  print $usage;
#  exit 0;
#}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname,'compara')->dbc;
my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomeDB');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MethodLinkSpeciesSet');

my $informant_gdb = $gdba->fetch_by_name_assembly($informant_species);
my $targeted_gdb = $gdba->fetch_by_name_assembly($targeted_species);
my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type,[$informant_gdb, $targeted_gdb]);


my $sql = "SELECT im.stable_id FROM
homology h, homology_member thm, member tm, homology_member ihm, member im 
WHERE h.homology_id=thm.homology_id AND 
thm.member_id=tm.member_id AND 
h.homology_id=ihm.homology_id AND 
ihm.member_id=im.member_id AND 
h.method_link_species_set_id = ? AND 
tm.genome_db_id = ? AND im.genome_db_id = ? AND 
ihm.perc_cov < ? AND thm.perc_cov > ? 
group by im.stable_id;";

my $sth = $dbc->prepare($sql);
$sth->execute($mlss->dbID, $targeted_gdb->dbID, $informant_gdb->dbID,$informant_perc_cov, $targeted_perc_cov);

$sql = "SELECT h.description,im.stable_id,im.chr_name,im.chr_start,im.chr_end,im.chr_strand,ihm.perc_cov,tm.stable_id,tm.chr_name,tm.chr_start,tm.chr_end,tm.chr_strand,thm.perc_cov FROM 
homology h, homology_member thm, member tm, homology_member ihm, member im 
WHERE h.homology_id=thm.homology_id AND 
thm.member_id=tm.member_id AND 
h.homology_id=ihm.homology_id AND 
ihm.member_id=im.member_id AND 
h.method_link_species_set_id = ? AND 
tm.genome_db_id = ? AND im.genome_db_id = ? AND 
im.stable_id = ?";

my $stable_id;
$sth->bind_columns(\$stable_id);

my $sth1 = $dbc->prepare($sql);

my $targeted_split_genes = 0;

while ($sth->fetch) {
  $sth1->execute($mlss->dbID, $targeted_gdb->dbID, $informant_gdb->dbID, $stable_id);

  next if ($sth1->rows < 2);

  my ($description,$im_stable_id,$im_chr_name,$im_chr_start,$im_chr_end,$im_chr_strand,$ihm_perc_cov,$tm_stable_id,$tm_chr_name,$tm_chr_start,$tm_chr_end,$tm_chr_strand,$thm_perc_cov);

  $sth1->bind_columns(\$description,\$im_stable_id,\$im_chr_name,\$im_chr_start,\$im_chr_end,\$im_chr_strand,\$ihm_perc_cov,\$tm_stable_id,\$tm_chr_name,\$tm_chr_start,\$tm_chr_end,\$tm_chr_strand,\$thm_perc_cov);

  my @split_gene_data = ();
  my $split_gene_chr;
  while ($sth1->fetch) {
    unless (defined $split_gene_chr) {
      $split_gene_chr = $tm_chr_name;
    }
    if ($ihm_perc_cov >$targeted_perc_cov) {# || $split_gene_chr ne $tm_chr_name) {
      @split_gene_data = ();
      $split_gene_chr = undef;
      last;
    }
    if (!$include_all && $split_gene_chr ne $tm_chr_name) {
      @split_gene_data = ();
      $split_gene_chr = undef;
      last;
    }
    push @split_gene_data, [$description,$im_stable_id,$im_chr_name,$im_chr_start,$im_chr_end,$im_chr_strand,$ihm_perc_cov,$tm_stable_id,$tm_chr_name,$tm_chr_start,$tm_chr_end,$tm_chr_strand,$thm_perc_cov];

  }
  if (scalar @split_gene_data) {
    foreach my $gene_piece (@split_gene_data) {
      print join(" ",@{$gene_piece}),"\n";
    }
    print "----\n";
    $targeted_split_genes++;
  }
}

print "Potentially $targeted_split_genes $targeted_species split genes\n";

exit 0;

__END__

select m2.stable_id,count(*) as count from homology h, homology_member hm1, member m1, homology_member hm2, member m2 where h.homology_id=hm1.homology_id and hm1.member_id=m1.member_id and h.homology_id=hm2.homology_id and hm2.member_id=m2.member_id and h.method_link_species_set_id=20002 and m1.genome_db_id=2 and m2.genome_db_id=1 and hm2.perc_cov<20 and hm1.perc_cov>70 group by m2.stable_id having count>1 order by count desc;



select h.description,m2.stable_id,hm2.perc_cov,m1.stable_id,hm1.perc_cov from homology h, homology_member hm1, member m1, homology_member hm2, member m2 where h.homology_id=hm1.homology_id and hm1.member_id=m1.member_id and h.homology_id=hm2.homology_id and hm2.member_id=m2.member_id and h.method_link_species_set_id=20002 and m1.genome_db_id=2 and m2.genome_db_id=1 and m2.stable_id in ('ENSG00000118997','ENSG00000132549','ENSG00000112159','ENSG00000155657','ENSG00000096696','ENSG00000102595','ENSG00000115850','ENSG00000129003','ENSG00000135899','ENSG00000167522','ENSG00000114841','ENSG00000158486','ENSG00000133401') order by m2.stable_id, h.description desc;

