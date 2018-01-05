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

use Bio::EnsEMBL::Registry;


#
# This script downloads all the paralogues of a given species
# and prints them by group (gene-tree). Given another species, it can
# also split the paralogues into "in-" and "out-" paralogues.
#
# NOTE: A group of paralogues (A1, A2, A3) will be printed only once,
#       the genes being listed in an arbitrary order
#

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara GenomeDB adaptor
my $genome_db_adaptor = $reg->get_adaptor("Multi", "compara", "GenomeDB");

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara homology adaptor
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

my $species = "human";
my $genome_db = $genome_db_adaptor->fetch_by_registry_name($species);

my $boundary_species = "mouse";
my $boundary_genome_db = $genome_db_adaptor->fetch_by_registry_name($boundary_species);

my $all_genes = $gene_member_adaptor->fetch_all_by_GenomeDB($genome_db);
my %protein_to_gene = map {$_->get_canonical_SeqMember->stable_id => $_->stable_id} @$all_genes;
warn "Loaded ", scalar(@$all_genes), " genes\n";

sub print_groups_of_paralogues {
    my ($gene_member, $paralogues, $txt_prefix, $seen) = @_;
    return unless scalar(@$paralogues);
    #print $txt_prefix, "\n";
    #map {print $_->toString(), "\n"} @$paralogues;
    my @para_stable_ids = map {$protein_to_gene{$_->get_all_Members()->[1]->stable_id}} @$paralogues;
    map {$seen->{$_} = 1} @para_stable_ids;
    my $paralogues_str = join(",", $gene_member->stable_id, @para_stable_ids);
    my $tree = $paralogues->[0]->gene_tree;
    my $tree_id = $tree->stable_id || $tree->get_value_for_tag('model_name');
    print join("\t", $tree_id, $txt_prefix, scalar(@$paralogues)+1, $paralogues_str), "\n";
}

my %seen = ();
my %seeni = ();
my %seeno = ();
# Comment the blocks according to your needs
foreach my $gene_member (@$all_genes) {
    unless ($seen{$gene_member->stable_id}) {
        # All paralogues
        my $all_paras = $homology_adaptor->fetch_all_by_Member($gene_member, -METHOD_LINK_TYPE => 'ENSEMBL_PARALOGUES');
        print_groups_of_paralogues($gene_member, $all_paras, 'all', \%seen);
    }
    unless ($seeni{$gene_member->stable_id}) {
        # In-paralogues
        my $in_paras = $homology_adaptor->fetch_all_in_paralogues_from_Member_NCBITaxon($gene_member, $boundary_genome_db->taxon);
        print_groups_of_paralogues($gene_member, $in_paras, 'in', \%seeni);
    }
    unless ($seeno{$gene_member->stable_id}) {
        # Out-paralogues
        my $out_paras = $homology_adaptor->fetch_all_out_paralogues_from_Member_NCBITaxon($gene_member, $boundary_genome_db->taxon);
        print_groups_of_paralogues($gene_member, $out_paras, 'out', \%seeno);
    }
}

