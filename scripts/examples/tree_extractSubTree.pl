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


#
# This scripts fetches the tree of a given gene, and prints the subtree of it
# which contains only genes from primates
#

use Bio::EnsEMBL::Registry;

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $gene_member_adaptor = $comparaDBA->get_GeneMemberAdaptor;
my $genetree_adaptor = $comparaDBA->get_GeneTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('FRY');

my @list = ("homo_sapiens", "pan_troglodytes", "pongo_pygmaeus", "macaca_mulatta", "gorilla_gorilla");
my $wanted_species;
foreach my $id (@list) {
  $wanted_species->{$id} = 1;
}

foreach my $gene (@$genes) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
  die "no members" unless (defined $member);

  # Fetch the gene tree
  my $genetree = $genetree_adaptor->fetch_default_for_Member($member);

  # List of unwanted leaves
  my @discarded_nodes;
  foreach my $leaf (@{$genetree->get_all_leaves}) {
    my $stable_id = $leaf->stable_id;
    unless ($wanted_species->{$leaf->genome_db->name}) {
      push @discarded_nodes, $leaf;
    }
  }

  # Compute the new tree
  my $ret_tree = $genetree->root->remove_nodes(\@discarded_nodes);

  # Print it
  $ret_tree->print_tree(10);
  print $ret_tree->newick_format("full"), "\n";

#   my $sa = $ret_tree->get_SimpleAlign;
#   # We can use bioperl to print out the aln in fasta format
#   my $filename = $gene->stable_id . ".fasta";
#   my $stdout_alignio = Bio::AlignIO->new
#     (-file => ">$filename",
#      -format => 'fasta');
#   $stdout_alignio->write_aln($sa);
#   print "# Alignment $filename\n";
}
