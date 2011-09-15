#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script gets the orthologue clusters starting from
# a specific gene and following the links (with a
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $gene_name = shift;
$gene_name="ENSDARG00000052960" unless(defined($gene_name));


# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $MA = $comparaDBA->get_MemberAdaptor;
my $gene_member = $MA->fetch_by_source_stable_id("ENSEMBLGENE", $gene_name);

my $ortho_set = {};
my $member_set = {};
get_orthologue_cluster($gene_member, $ortho_set, $member_set, 0);

printf("cluster has %d links\n", scalar(keys(%{$ortho_set})));
printf("cluster has %d genes\n", scalar(keys(%{$member_set})));

foreach my $homology (values(%{$ortho_set})) {
  $homology->print_homology;
}
foreach my $member (values(%{$member_set})) {
  $member->print_member;
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

