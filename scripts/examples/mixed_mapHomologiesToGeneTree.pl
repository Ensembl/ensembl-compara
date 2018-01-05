#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
my $genetree_adaptor = $comparaDBA->get_GeneTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

foreach my $gene (@$genes) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member);
  foreach my $homology (@$all_homologies) {
    my @two_stable_ids = map { $_->stable_id } @{$homology->get_all_Members};
    my $ancestor_tree_node = $homology->gene_tree_node;
    my $distance_a = $ancestor_tree_node->find_leaf_by_name($two_stable_ids[0])->distance_to_ancestor($ancestor_tree_node);
    my $distance_b = $ancestor_tree_node->find_leaf_by_name($two_stable_ids[1])->distance_to_ancestor($ancestor_tree_node);
    print join(",",
        $two_stable_ids[0],
        $two_stable_ids[1],
        $homology->is_tree_compliant,
        $homology->taxonomy_level,
        $homology->species_tree_node->get_divergence_time(),
        $distance_a,
        $distance_b,
    ),"\n";
  }
}
