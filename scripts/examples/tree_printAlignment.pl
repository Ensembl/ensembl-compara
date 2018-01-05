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

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $gene_member_adaptor = $comparaDBA->get_GeneMemberAdaptor;
my $genetree_adaptor = $comparaDBA->get_GeneTreeAdaptor;

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

foreach my $gene (@$genes) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
  die "no members" unless (defined $member);

  # Fetch the tree
  my $genetree = $genetree_adaptor->fetch_default_for_Member($member);
  next unless $genetree;

  # Get the protein multialignment and the back-translated CDS alignment
  my $protein_align = $genetree->get_SimpleAlign;
  my $cds_align = $genetree->get_SimpleAlign(-seq_type => 'cds');

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
  print "Your file $filename has been generated\n";
}
