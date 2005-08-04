#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;

my $help = 0;
my $usage = "usage\n";
my $method_link_type = "ENSEMBL_ORTHOLOGUES";
my ($informant_species, $targeted_species);
my ($dbname,$reg_conf);

my $informant_perc_cov = 20;
my $targeted_perc_cov = 70;
my $no_chr_constraint = 0;
my $html = 0;

GetOptions('help' => \$help,
           'dbname=s' => \$dbname,
           'informant=s' => \$informant_species,
           'informant_perc_cov=s' => \$informant_perc_cov,
           'targeted=s' => \$targeted_species,
           'targeted_perc_cov=s' => \$targeted_perc_cov,
           'no_chr_constraint' => \$no_chr_constraint,
           'method_link_type=s' => \$method_link_type,
           'reg_conf=s' => \$reg_conf,
           'html' => \$html);

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
my %stable_ids;
my ($min_start, $max_end);

if ($html) {
  print qq(
           <HTML>
           <HEAD>
           <TITLE>Split genes in Ensembl</TITLE>
           </HEAD>
           <P></P>
           <H2 align=center>Possible split genes in <i>$targeted_species</i><br>using <i>$informant_species</i> as informant</H2>
           <P></P>
           <HR></HR>
          );
} else {
  print "#Possible split genes in $targeted_species
#using $informant_species as informant\n";
}

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
    if (!$no_chr_constraint && $split_gene_chr ne $tm_chr_name) {
      @split_gene_data = ();
      $split_gene_chr = undef;
      last;
    }
    push @split_gene_data, [$description,$im_stable_id,$im_chr_name,$im_chr_start,$im_chr_end,$im_chr_strand,$ihm_perc_cov,$tm_stable_id,$tm_chr_name,$tm_chr_start,$tm_chr_end,$tm_chr_strand,$thm_perc_cov];
    $min_start = $tm_chr_start unless (defined $min_start);
    $min_start = $tm_chr_start if ($min_start > $tm_chr_start);
    $max_end = $tm_chr_end unless (defined $max_end);
    $max_end = $tm_chr_end if ($max_end < $tm_chr_end);
    $stable_ids{$im_stable_id} =1;
    $stable_ids{$tm_stable_id} =1;
  }
  if (scalar @split_gene_data) {
    print "<pre>\n" if ($html);
    printf "#%-5s %20s %5s %9s %9s %6s %3s %20s %5s %9s %9s %6s %3s\n", qw(desc stable_id chr start end strand cov stable_id chr start end strand cov);
    foreach my $gene_piece (@split_gene_data) {
      printf " %-5s %20s %5s %9d %9d %6s %3d %20s %5s %9d %9d %6s %3d\n",@{$gene_piece};
    }
    print "</pre>\n" if ($html);
    if ($html) {
      $informant_species =~ s/\s+/_/;
      my $c = $im_chr_name;
      $c .= ":" . int($im_chr_start + ($im_chr_end - $im_chr_start + 1)/2);
      $c .= ":" . 1;
      my $w = $im_chr_end - $im_chr_start + 10000;
      my $h = join("|", keys %stable_ids);
      my $s1 = join("", map(lc substr($_,0,1), (split(/\s+/,$targeted_species))));
      my $c1 = $tm_chr_name;
      $c1 .= ":" . int($min_start + ($max_end - $min_start + 1)/2);
      $c1 .= ":" . $im_chr_strand*$tm_chr_strand;
      my $w1 = $max_end - $min_start + 10000;
      print qq(
See in <A HREF="http://www.ensembl.org/$informant_species/multicontigview?c=$c;w=$w;h=$h;s1=$s1;c1=$c1;w1=$w1">MultiContigView</A>
              );
      print "<hr></hr>\n";
    } else {
      print "#----\n";
    }
    $targeted_split_genes++;
  }
  %stable_ids = ();
  $min_start = undef;
  $max_end = undef;
}
if ($html) {
print qq
  (
<p>#Potentially $targeted_split_genes $targeted_species split genes</p>
</BODY>
   </HTML>
  );
} else {
  print "#Potentially $targeted_split_genes $targeted_species split genes\n";
}



exit 0;

__END__
