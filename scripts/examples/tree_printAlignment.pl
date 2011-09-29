#!/usr/bin/env perl

use strict;
use warnings;


#
# This script fetches the gene tree of a given human gene, and prints
# the multiple alignment of the family
#

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');
my $member_adaptor = $comparaDBA->get_MemberAdaptor;
my $proteintree_adaptor = $comparaDBA->get_ProteinTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

foreach my $gene (@$genes) {
  my $member = $member_adaptor->
    fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  die "no members" unless (defined $member);

  # Fetch the proteintree
  my $proteintree =  $proteintree_adaptor->
    fetch_by_gene_Member_root_id($member);

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
