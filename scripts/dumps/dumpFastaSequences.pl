#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-treefam-prod',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4401,
     -species => 'Multi',
     -dbname => 'mateus_tuatara_86',
);

my $seq_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "SeqMember" );
my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "GeneMember" );

#Working directory
my $work_dir = "/nfs/production/panda/ensembl/compara/mateus/tuatara_phylogeny/all_species/promoted/";

#Input file with the homology groups.
#It expects one group per line, each line will result in a separate fasta file.
my $input_one2one = "$work_dir/filtered_promoted_one2ones.txt";

my %one2one;
my $tree_count = 0;

open(IN,$input_one2one);
while(<IN>){
    chomp($_);
    @{ $one2one{$tree_count} } = split(/\,/,$_);
    $tree_count++;
}

foreach my $tree ( keys %one2one ) {
    #Protein sequence:
    open(PROT,">$work_dir/seq/tree_$tree\_prot.fasta");

    #DNA sequences:
    open(CDS,">$work_dir/seq/tree_$tree\_cds.fasta");
    foreach my $id (@{$one2one{$tree}}) {
        my $gene_member = $gene_member_adaptor->fetch_by_stable_id($id);
        my $seq_member  = $gene_member->get_canonical_SeqMember();
        my $species_name= $gene_member->genome_db->name();

        print PROT ">" . $seq_member->stable_id() . "|$species_name\n";
        print PROT $seq_member->sequence() . "\n";
        print CDS ">" . $seq_member->stable_id() . "|$species_name\n";
        print CDS $seq_member->other_sequence('cds') . "\n";

    }
    close(PROT);
    close(CDS);
}
