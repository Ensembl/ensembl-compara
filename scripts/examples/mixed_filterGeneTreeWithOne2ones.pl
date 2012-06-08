#!/usr/bin/env perl

use strict;
use warnings;

use Bio::AlignIO;
use Bio::EnsEMBL::Registry;


#
# This script fetches the gene tree associated to a given gene, and
# filters it to keep only one2one orthologs (with respect to the
# initial gene). It finally prints the multiple alignment of the
# remaining genes
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
my $genetree_adaptor = $comparaDBA->get_GeneTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('PAX2');

my $stdout_alignio = Bio::AlignIO->newFh(-format => 'clustalw');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_all_by_Member($member);

  my %leaves_names;
  $leaves_names{$gene->stable_id} = 1;
  foreach my $homology (@$all_homologies) {
    next unless ($homology->description =~ /one2one/);
    my ($gene1,$gene2) = @{$homology->gene_list};
    my $temp;
    unless ($gene1->stable_id =~ /ENSG0/) {
      $temp = $gene1;
      $gene1 = $gene2;
      $gene2 = $temp;
    }
    $leaves_names{$gene2->stable_id} = 1;
  }

  # Fetch the gene tree
  my $genetree = $genetree_adaptor->fetch_all_by_Member($member)->[0];

  # Delete the part that is not one2one wrt the human gene
  foreach my $leaf (@{$genetree->get_all_leaves}) {
    my $gene_name = $leaf->gene_member->stable_id;
    unless (defined $leaves_names{$gene_name}) {
      $leaf->disavow_parent;
    }
  }
  $genetree = $genetree->minimize_tree;

  # Print the minimized tree
  $genetree->print_tree;

  # Obtain the MSA for human and all one2ones
  my $protein_align = $genetree->root->get_SimpleAlign;
  print $stdout_alignio $protein_align;
  $genetree->release_tree;
}

