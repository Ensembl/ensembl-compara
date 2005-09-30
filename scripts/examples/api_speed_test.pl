#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Switch;
use Time::HiRes qw(time gettimeofday tv_interval);

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');

# get GenomeDB for human
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");

my $ma = $comparaDBA->get_MemberAdaptor;

my $MA = $comparaDBA->get_MemberAdaptor;
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000014138");





my $count=0;
my $sum=0;
while($count <10) {
  $count++;
  my $load_starttime = time();

  switch(2) {
    case 1 { test_interface(); }
    case 2 { 
      my $ortho_set = {};
      my $member_set = {};
      get_orthologue_cluster($gene_member, $ortho_set, $member_set, 0);
    }
  }
  
  my $tdif = time()-$load_starttime;
  $sum += $tdif;
  printf("%10.2fsec to test\n", $tdif);
}

my $avg = $sum / $count;
printf("avg time : %10.2f\n", $avg);

exit(0);



sub test_interface
{
  my $m1 = $ma->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");
  $m1->get_Gene;

  my $members = $ma->fetch_by_source_taxon("ENSEMBLPEP", $humanGDB->taxon_id);

  foreach my $m2 (@{$members}) {
    next unless($m2->chr_name eq $m1->chr_name);
    $m2->get_Gene;  
  }
}


sub get_orthologue_cluster {
  my $gene = shift;
  my $ortho_set = shift;
  my $member_set = shift;
  my $debug = shift;

  return if($member_set->{$gene->dbID});

  $gene->print_member("query gene\n") if($debug);
  $member_set->{$gene->dbID} = $gene;

  my $homologies = $comparaDBA->get_HomologyAdaptor->fetch_by_Member($gene);
  printf("fetched %d homologies\n", scalar(@$homologies)) if($debug);

  foreach my $homology (@{$homologies}) {
    next if($ortho_set->{$homology->dbID});
    next if($homology->method_link_type ne 'ENSEMBL_ORTHOLOGUES');

    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      next if($member->dbID == $gene->dbID); #skip query gene
      $member->print_member if($debug);

      printf("adding homology_id %d to cluster\n", $homology->dbID) if($debug);
      $ortho_set->{$homology->dbID} = $homology;
      get_orthologue_cluster($member, $ortho_set, $member_set, $debug);
    }
  }
  printf("done with search query %s\n", $gene->stable_id) if($debug);
}
