#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;
use Bio::AlignIO;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous", 
   -db_version=>'57');
my $human_gene_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Homo sapiens", "core", "Gene");
my $member_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "Member");
my $proteintree_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor
  ("Compara", "compara", "ProteinTree");

my $genes = $human_gene_adaptor->
  fetch_all_by_external_name('FRY');

my @list = ("Homo sapiens","Pan troglodytes","Pongo pygmaeus","Macaca mulatta","Gorilla gorilla");
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

  my @discarded_nodes;
  foreach my $leaf (@{$proteintree->get_all_leaves}) {
    my $stable_id = $leaf->stable_id;
    # since you are interested in Euteleostomi, means you need to get
    # rid of the cionas and anything which stable_id doesn't start by
    # ENS
    unless ($wanted_species->{$leaf->genome_db->name}) {
    # The following commented line would do the same but it's much slower
    # if ($leaf->genome_db->taxon->classification !~ /Euteleostomi/) {}
      push @discarded_nodes, $leaf;
    }
  }
  my $ret_tree = $proteintree->remove_nodes(\@discarded_nodes);
  print $ret_tree->newick_format,"\n";

#   my $sa = $ret_tree->get_SimpleAlign;
#   # We can use bioperl to print out the aln in fasta format
#   my $filename = $gene->stable_id . ".fasta";
#   my $stdout_alignio = Bio::AlignIO->new
#     (-file => ">$filename",
#      -format => 'fasta');
#   $stdout_alignio->write_aln($sa);
#   print "# Alignment $filename\n";
}
