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

#
# This script creates FASTA files for a list of genes.
# It generates protein and DNA sequences
#

use strict;
use warnings;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::MemberSet;

# Parameters
#-----------------------------------------------------------------------------------------------------
#URL to the compara database containing the homologies
my $compara_url;

#Input file with the homology groups.
#It expects one group per line, each line will result in a separate file.
my $input_file;

#Directory to print out the results
my $out_dir = '.';

#File format output (formats are from bioperl)
my $format = 'fasta';

#-----------------------------------------------------------------------------------------------------
# Command line example:
#   perl dumpSequences.pl -compara_url mysql://ensro@mysql-treefam-prod:4401/mateus_tuatara_86 -input_file /nfs/production/panda/ensembl/compara/mateus/tuatara_phylogeny/all/promoted/promoted_ids.txt -out_dir /nfs/production/panda/ensembl/compara/mateus/tuatara_phylogeny/all/promoted/seq/promoted/ -format fasta
#-----------------------------------------------------------------------------------------------------

# Parse command line
GetOptions( "compara_url=s" => \$compara_url, "input_file=s" => \$input_file, "out_dir=s" => \$out_dir, "format=s" => \$format ) or die("Error in command line arguments\n");

die
  "Error in command line arguments [compara_url = mysql://user\@server/db] [input_file = /your/directory/input_file] [out_dir = /your/directory/] [format = your_format, default is fasta]"
  if ( !$compara_url || !$input_file || !$out_dir || !$format );

#-----------------------------------------------------------------------------------------------------

# Adaptors
#-----------------------------------------------------------------------------------------------------
my $compara_dba         = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $compara_url );
my $seq_member_adaptor  = $compara_dba->get_SeqMemberAdaptor;
my $gene_member_adaptor = $compara_dba->get_GeneMemberAdaptor;

#-----------------------------------------------------------------------------------------------------

# Extract IDs from the input file
#-----------------------------------------------------------------------------------------------------
my %one2one;
my $tree_count = 0;

    use Data::Dumper;

open my $fh, $input_file || die "Could not open file $input_file";
while (<$fh>) {
    chomp($_);
    @{ $one2one{$tree_count} } = split( /\t/, $_ );
    $tree_count++;
}
close($fh);

#-----------------------------------------------------------------------------------------------------

#Main loop to iterate through all the groups
#-----------------------------------------------------------------------------------------------------
foreach my $tree ( sort keys %one2one ) {
    #print Dumper $one2one{$tree};
    my @seq_members;
    my $gene_members = $gene_member_adaptor->fetch_all_by_stable_id_list( [ @{ $one2one{$tree} } ] ) || die "Could not fetch by stable_id_list";

    foreach my $gene_member ( @{$gene_members} ) {
        my $seq_member = $gene_member->get_canonical_SeqMember();
        push( @seq_members, $seq_member );
    }

    my $member_set = Bio::EnsEMBL::Compara::MemberSet->new( -members => \@seq_members );

    #Protein sequence:
    $member_set->print_sequences_to_file( "$out_dir/tree_$tree\_prot.$format", -APPEND_SP_NAME => 1, -ID_TYPE => 'STABLE_GENE', -format => $format ) || die "Could not print protein sequence into file";

    #DNA sequences
    $member_set->print_sequences_to_file( "$out_dir/tree_$tree\_cds.$format", -APPEND_SP_NAME => 1, -ID_TYPE => 'STABLE_GENE', -SEQ_TYPE => 'cds', -format => $format ) || die "Could not print CDS sequence into file";
}

#-----------------------------------------------------------------------------------------------------
