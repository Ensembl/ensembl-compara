#!/usr/local/bin/perl
use strict;
use Bio::EnsEMBL::Registry;
use Getopt::Long;

# Fetch a list of ENSG ids and get the protein alignment for them. Print
# the alignment in clustalw format on a list of files

my ($inputfile,$debug);

GetOptions(
	   'i|input|inputfile:s' => \$inputfile,
           'd|debug:s' => \$debug,
          );

Bio::EnsEMBL::Registry->load_registry_from_db
  (-host=>"ensembldb.ensembl.org", 
   -user=>"anonymous");
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

open INPUT,"$inputfile" or die "$!\n";
my @gene_ids;
while (<INPUT>) {
  chomp $_;
  next if ($_ !~ /ENSG0/);
  push @gene_ids, $_;
}

foreach my $gene_id (@gene_ids) {
  my $gene = $human_gene_adaptor->
    fetch_by_stable_id($gene_id);
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  unless (defined $member) {
    print "# No members for $gene_id\n";
    next;
  }

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_Member_root_id($member);
  unless (defined $proteintree) {
    print "# No alignment for $gene_id\n";
    next;
  }

#   foreach my $leaf (@{$proteintree->get_all_leaves}) {
#       print $leaf->description, "\n";
#   }

#   # Show the tree
#   print "\n", $proteintree->newick_format("display_label_composite"), "\n\n";
#   print $proteintree->nhx_format("display_label_composite"), "\n\n";
#   $proteintree->print_tree(10);

  # Get the protein multialignment and the back-translated CDS alignment
  my $protein_align = $proteintree->get_SimpleAlign;
  # my $cds_align = $proteintree->get_SimpleAlign(-cdna=>1);

  eval {require Bio::AlignIO;};
  last if ($@);
  # We can use bioperl to print out the aln in fasta format
  my $filename = $gene->stable_id . ".clustalw";
  my $stdout_alignio = Bio::AlignIO->new
    (-file => ">$filename",
     -format => 'clustalw');
  $stdout_alignio->write_aln($protein_align);
  print "# Alignment $filename\n";

  # We can print out the aln in phylip format, with a space between
  # each codon (tag_length = 3)
  #   my $phylip_alignio = Bio::AlignIO->new
  #     (-file => ">$filename",
  #     -format => 'clustalw');
  #   $phylip_alignio->write_aln($cds_align);
  #   print STDERR "Your file $filename has been generated\n";
}
