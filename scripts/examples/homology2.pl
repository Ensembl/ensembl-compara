#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous", 
   -db_version=>'58');
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
  fetch_all_by_external_name('BRCA2');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);
  my $all_homologies = $homology_adaptor->fetch_by_Member($member);

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_gene_Member_root_id($member);

  foreach my $leaf (@{$proteintree->get_all_leaves}) {
      print $leaf->description, "\n";
  }

  # Show the tree
  print "\n", $proteintree->newick_format("display_label_composite"), "\n\n";
  print $proteintree->nhx_format("display_label_composite"), "\n\n";
  $proteintree->print_tree(10);

  # Get the protein multialignment and the back-translated CDS alignment
  my $protein_align = $proteintree->get_SimpleAlign;
  my $cds_align = $proteintree->get_SimpleAlign(-cdna=>1);

  eval {require Bio::AlignIO;};
  last if ($@);
  # We can use bioperl to print out the aln in fasta format
  my $stdout_alignio = Bio::AlignIO->new
    (-fh => \*STDOUT,
     -format => 'fasta');
  $stdout_alignio->write_aln($protein_align);

  my $filename = $gene->stable_id . ".phylip";

  # We can print out the aln in phylip format, with a space between
  # each codon (tag_length = 3)
  my $phylip_alignio = Bio::AlignIO->new
    (-file => ">$filename",
    -format => 'phylip',
    -tag_length => 3,
    -interleaved => 1,
    -idlength => 30);
  $phylip_alignio->write_aln($cds_align);
  print STDERR "Your file $filename has been generated\n";
}
