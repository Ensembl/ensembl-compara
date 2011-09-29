#!/usr/bin/env perl

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

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $member_adaptor = $comparaDBA->get_MemberAdaptor;
my $proteintree_adaptor = $comparaDBA->get_ProteinTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('FRY');

my @list = ("homo_sapiens", "pan_troglodytes", "pongo_pygmaeus", "macaca_mulatta", "gorilla_gorilla");
my $wanted_species;
foreach my $id (@list) {
  $wanted_species->{$id} = 1;
}

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_Member_root_id($member);

  # List of unwanted leaves
  my @discarded_nodes;
  foreach my $leaf (@{$proteintree->get_all_leaves}) {
    my $stable_id = $leaf->stable_id;
    unless ($wanted_species->{$leaf->genome_db->name}) {
      push @discarded_nodes, $leaf;
    }
  }

  # Compute the new tree
  my $ret_tree = $proteintree->remove_nodes(\@discarded_nodes);

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
