#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Time::HiRes qw { time };

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;

my $reg_conf = shift;
my $gene_name = shift;
$gene_name="ENSDARG00000052960" unless(defined($gene_name));

die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

###########################
# 
# advanced example which uses a recursive approach
# to build single linkage clusters within the orthologues
# by starting at a specific gene and following the links
#
###########################

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');


my $MA = $comparaDBA->get_MemberAdaptor;
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", $gene_name);

my $start = time();
my $ortho_set = {};
my $member_set = {};
get_orthologue_cluster($gene_member, $ortho_set, $member_set, 0);

printf("cluster has %d links\n", scalar(keys(%{$ortho_set})));
printf("cluster has %d genes\n", scalar(keys(%{$member_set})));
printf("%1.3f msec\n", 1000.0*(time() - $start));

foreach my $homology (values(%{$ortho_set})) {
  $homology->print_homology;
}
foreach my $member (values(%{$member_set})) {
  $member->print_member;
}


exit(0);


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


1;
