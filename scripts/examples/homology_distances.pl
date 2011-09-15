#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script fetches the Compara tree of PAX6, identifies
# the PAX6 leaf, and a random zebrafish leaf. It prints the
# distances to these leaves from the root and their last
# common ancestor
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor ("Homo sapiens", "core", "Gene");
my $member_adaptor = $reg->get_adaptor ("Compara", "compara", "Member");
my $homology_adaptor = $reg->get_adaptor ("Compara", "compara", "Homology");
my $proteintree_adaptor = $reg->get_adaptor ("Compara", "compara", "ProteinTree");
my $mlss_adaptor = $reg->get_adaptor ("Compara", "compara", "MethodLinkSpeciesSet");

my $genes = $human_gene_adaptor-> fetch_all_by_external_name('PAX6');

foreach my $gene (@$genes) {
  my $member = $member_adaptor-> fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->fetch_by_Member_root_id($member);
  my $all_leaves = $proteintree->get_all_leaves_indexed();

  my $node_h;
  my $node_z;

  while (my $leaf = shift @$all_leaves) {
  	# finds a zebrafish gene
      $node_z = $leaf if ($leaf->taxon_id == 7955);
	# finds the query gene
	$node_h = $leaf if ($leaf->stable_id eq $member->get_canonical_peptide_Member->stable_id);
  }
  $node_h->print_member;
  $node_z->print_member,

  print "root to human: ", $node_h->distance_to_ancestor($proteintree), "\n";
  print "root to zebra: ", $node_z->distance_to_ancestor($proteintree), "\n";

  my $ancestor = $node_z->find_first_shared_ancestor($node_h);
  print "lca to human: ", $node_h->distance_to_ancestor($ancestor), "\n";
  print "lca to zebra: ", $node_z->distance_to_ancestor($ancestor), "\n";
  
}
