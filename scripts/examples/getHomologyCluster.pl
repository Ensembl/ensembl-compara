#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Time::HiRes qw { time };

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

###########################
# 
# advanced example which uses a recursive approach
# to build single linkage clusters within a species set
#
###########################

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');

# build a species set with a hash that is easy to test against 
my $human = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $mouse = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");
my $chicken = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("chicken");
my $species_set = {};
$species_set->{$human->dbID} = 1;
$species_set->{$mouse->dbID} = 1;
$species_set->{$chicken->dbID} = 1;


my $MA = $comparaDBA->get_MemberAdaptor;
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", "ENSG00000060069");

my $start = time();
my $ortho_set = {};
get_orthologue_cluster($gene_member, $species_set, $ortho_set, 0);

printf("cluster has %d links\n", scalar(keys(%{$ortho_set})));
printf("%1.3f msec\n", 1000.0*(time() - $start));

foreach my $homology (values(%{$ortho_set})) {
  $homology->print_homology;
}


exit(0);


sub get_orthologue_cluster {
  my $gene = shift;
  my $species_set = shift;
  my $ortho_set = shift;
  my $debug = shift;

  $gene->print_member("query gene\n") if($debug);

  my $homologies = $comparaDBA->get_HomologyAdaptor->fetch_by_Member($gene);
  printf("fetched %d homologies\n", scalar(@$homologies)) if($debug);

  foreach my $homology (@{$homologies}) {
    next if($ortho_set->{$homology->dbID});
    next if($homology->method_link_type ne 'ENSEMBL_ORTHOLOGUES');

    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      next if($member->dbID == $gene->dbID); #skip query gene
      $member->print_member if($debug);
      next unless($species_set->{$member->genome_db_id});
      print("YES in species set\n") if($debug);

      printf("adding homology_id %d to cluster\n", $homology->dbID) if($debug);
      $ortho_set->{$homology->dbID} = $homology;
      get_orthologue_cluster($member, $species_set, $ortho_set, $debug);
    }
  }
  printf("done with search query %s\n", $gene->stable_id) if($debug);
}


1;
