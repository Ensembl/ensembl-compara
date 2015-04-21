#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $gene_member_adaptor = $comparaDBA->get_GeneMemberAdaptor;
my $homology_adaptor = $comparaDBA->get_HomologyAdaptor;
my $genetreenode_adaptor = $comparaDBA->get_GeneTreeNodeAdaptor;
my $ncbitaxon_adaptor = $comparaDBA->get_NCBITaxonAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

my $verbose = 0;
foreach my $gene (@$genes) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member);
  foreach my $homology (@$all_homologies) {
    my @two_ids = map { $_->seq_member_id } @{$homology->get_all_Members};
    my $tree_node = $homology->gene_tree_node;
    my $node_a = $genetreenode_adaptor->fetch_default_AlignedMember_for_Member($two_ids[0]);
    my $node_b = $genetreenode_adaptor->fetch_default_AlignedMember_for_Member($two_ids[1]);
    $node_a->root->merge_node_via_shared_ancestor($node_b);
    my $ancestor = $node_a->find_first_shared_ancestor($node_b);
    $ancestor->print_tree(20) if ($verbose);
    my $distance_a = $node_a->distance_to_ancestor($ancestor);
    my $distance_b = $node_b->distance_to_ancestor($ancestor);
    print $node_a->stable_id, ",",
          $node_b->stable_id, ",",
          $ancestor->get_tagvalue("taxon_name"), ",",
          $ncbitaxon_adaptor->fetch_by_dbID($ancestor->get_tagvalue('taxon_id'))->get_tagvalue('ensembl timetree mya'), ",",
          $tree_node->taxonomy_level, ",",
          $distance_a, ",",
          $distance_b, "\n";
  }
}
