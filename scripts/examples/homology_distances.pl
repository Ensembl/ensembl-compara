#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;
use Bio::TreeIO;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous", 
   -db_version=>'48');
my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "Member");
my $homology_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "Homology");
my $proteintree_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "ProteinTree");
my $mlss_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "MethodLinkSpeciesSet");

my $genes = $human_gene_adaptor->
  fetch_all_by_external_name('PAX6');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_Member_root_id($member);

  my $node_a = $proteintree->find_node_by_name("ENSDARP00000066224");
  my $node_b = $proteintree->find_node_by_name("ENSP00000241001");
  my $ancestor = $node_a->find_first_shared_ancestor($node_b);
  my $distance_a = $node_a->distance_to_ancestor($ancestor);
  my $distance_b = $node_b->distance_to_ancestor($ancestor);

  my $newick = $proteintree->newick_format;
  my $nhx = $proteintree->nhx_format;

  open(my $fake_nh, "+<", \$newick);
  my $nhin = new Bio::TreeIO
    (-fh => $fake_nh,
     -format => 'newick');
  my $nht = $nhin->next_tree;
  $nhin->close;

  open(my $fake_nhx, "+<", \$nhx);
  my $nhxin = new Bio::TreeIO
    (-fh => $fake_nhx,
     -format => 'nhx');
  my $nhxt = $nhxin->next_tree;
  $nhxin->close;
}
