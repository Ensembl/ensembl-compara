#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous", 
   -db_version=>'58');

my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor("Compara", "compara", "Homology");
my $proteintree_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "ProteinTree");

my $genes = $human_gene_adaptor->fetch_all_by_external_name('PAX2');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

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

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_gene_Member_root_id($member);

  # Delete the part that is not one2one wrt the human gene
  foreach my $leaf (@{$proteintree->get_all_leaves}) {
    my $leaf_description = $leaf->description;
    $leaf_description =~ /Gene\:(\S+)/;
    my $gene_name = $1;
    unless (defined $leaves_names{$gene_name}) {
      $leaf->disavow_parent;
      $proteintree = $proteintree->minimize_tree;
    }
  }
  # Obtain the MSA for human and all one2ones
  my $protein_align = $proteintree->get_SimpleAlign;
  $proteintree->release_tree;
}
