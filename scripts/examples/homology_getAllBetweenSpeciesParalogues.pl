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

use Bio::EnsEMBL::Compara::Utils::Preloader;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


## Get the compara mlss adaptor
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
## Get the compara homology adaptor
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");
## Get the compara gene tree adaptor
my $gene_tree_adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");
## Get the compara gene-member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");


## Species definition
my $species1 = 'human';
my $species2 = 'mouse';

## Get the MethodLinkSpeciesSet object describing the orthology between the two species
my $this_mlss = $mlss_adaptor->fetch_by_method_link_type_registry_aliases('ENSEMBL_ORTHOLOGUES', [$species1, $species2]);

## The two GenomeDB objects (one is human, the other one is mouse)
my ($gdb1, $gdb2) = @{$this_mlss->species_set->genome_dbs};

my %gene_member_id_2_stable_id = ();
foreach my $gdb ($gdb1, $gdb2) {
    my $genes = $gene_member_adaptor->fetch_all_by_GenomeDB($gdb);
    $gene_member_id_2_stable_id{$_->dbID} = $_->stable_id for @$genes;
    warn "Loaded ", scalar(@$genes), " ", $gdb->name, " gene names\n";
}

## Get all the homologues
my $all_homologies = $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($this_mlss);

Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($reg->get_adaptor("Multi", "compara", "AlignedMember"), $all_homologies);

my %orthologues = ();
## For each homology
foreach my $this_homology (@{$all_homologies}) {
    $orthologues{$this_homology->get_all_Members()->[0]->stable_id."/".$this_homology->get_all_Members()->[1]->stable_id} = 1;
    $orthologues{$this_homology->get_all_Members()->[1]->stable_id."/".$this_homology->get_all_Members()->[0]->stable_id} = 1;
}
warn "Loaded ", scalar(@$all_homologies), " orthologies\n";

my $all_protein_trees = $gene_tree_adaptor->fetch_all(
    -CLUSTERSET_ID => 'default',
    -MEMBER_TYPE => 'protein',
    -TREE_TYPE => 'tree',
);
warn "Loaded ", scalar(@$all_protein_trees), " protein-trees\n";

sub print_pairs {
    my ($all_g1, $all_g2, $extra) = @_;
    foreach my $g1 (@$all_g1) {
        foreach my $g2 (@$all_g2) {
            if (not $orthologues{$g1->stable_id."/".$g2->stable_id}) {
                print join("\t", $gene_member_id_2_stable_id{$g1->gene_member_id}, $g1->stable_id, $gene_member_id_2_stable_id{$g2->gene_member_id}, $g2->stable_id, @$extra), "\n";
            }
        }
    }
}

sub process {
    my $node = shift;
    if ($node->is_leaf) {
        if ($node->genome_db_id == $gdb1->dbID) {
            return [[$node], []];
        } elsif ($node->genome_db_id == $gdb2->dbID) {
            return [[], [$node]];
        } else {
            return [[], []];
        }
    }
    my @splits = map {process($_)} @{$node->children};
    my $extra = [$node->taxonomy_level, $node->duplication_confidence_score];
    print_pairs($splits[0]->[0], $splits[1]->[1], $extra);
    print_pairs($splits[1]->[0], $splits[0]->[1], $extra);
    return [ [@{$splits[0]->[0]}, @{$splits[1]->[0]}], [@{$splits[0][1]}, @{$splits[1][1]}] ];
}

my $n = 0;
foreach my $tree (@$all_protein_trees) {
    process($tree->root);
    # Another approach that lacks the information about the duplication node
    #my $all_g1 = $tree->get_Member_by_GenomeDB($gdb1);
    #my $all_g2 = $tree->get_Member_by_GenomeDB($gdb2);
    #print_pairs($all_g1, $all_g2, [$tree->stable_id]);
    $tree->release_tree();
    $n++;
    warn "[$n/", scalar(@$all_protein_trees), " trees processed]\n" unless $n % 1;
}


