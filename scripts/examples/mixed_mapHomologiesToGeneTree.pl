#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara database to fetch all the homologies
# attached to a given gene, and then prints information about last
# common ancestor and branch length using the gene tree
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $member_adaptor = $comparaDBA->get_MemberAdaptor;
my $homology_adaptor = $comparaDBA->get_HomologyAdaptor;
my $proteintree_adaptor = $comparaDBA->get_ProteinTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

my $verbose = 0;
foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member);
  foreach my $homology (@$all_homologies) {
    my @two_ids = map { $_->get_canonical_Member->member_id } @{$homology->gene_list};
    my $leaf_node_id = $homology->node_id;
    my $tree = $proteintree_adaptor->fetch_node_by_node_id($leaf_node_id);
    my $node_a = $proteintree_adaptor->fetch_AlignedMember_by_member_id_root_id($two_ids[0],1);
    my $node_b = $proteintree_adaptor->fetch_AlignedMember_by_member_id_root_id($two_ids[1],1);
    my $root = $node_a->subroot;
    $root->merge_node_via_shared_ancestor($node_b);
    my $ancestor = $node_a->find_first_shared_ancestor($node_b);
    $ancestor->print_tree(20) if ($verbose);
    my $distance_a = $node_a->distance_to_ancestor($ancestor);
    my $distance_b = $node_b->distance_to_ancestor($ancestor);
    print $node_a->stable_id, ",",
          $node_b->stable_id, ",",
          $ancestor->get_tagvalue("taxon_name"), ",",
          $ancestor->get_tagvalue("taxon_alias_mya"), ",",
          $tree->get_tagvalue("taxon_name"), ",",
          $distance_a, ",",
          $distance_b, "\n";
  }
}
