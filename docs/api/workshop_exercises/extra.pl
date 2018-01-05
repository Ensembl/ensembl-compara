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

## Get the human gene adaptor
my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the Compara adaptors
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");
my $family_adaptor = $reg->get_adaptor("Multi", "compara", "Family");
my $gene_tree_adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");


## Part 1
##########

## Get all existing gene object with the name SAFB
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('SAFB');

# Trick: the instructor confirmed that there is a single such human gene
my $this_gene = $these_genes->[0];


print $this_gene->source(), " ", $this_gene->stable_id(), ": ", $this_gene->description(), "\n";

## Get the compara member
my $gene_member = $gene_member_adaptor->fetch_by_stable_id($this_gene->stable_id());

## Print some info for this member
print $gene_member->toString(), "\n";


## Part 2
##########


## Get all the families
my $all_families = $family_adaptor->fetch_all_by_GeneMember($gene_member);

my $relevant_family = undef;

## For each family
foreach my $this_family (@{$all_families}) {

    # To discard the artifact family
    if (scalar(@{$this_family->get_all_Members}) > 10) {
        $relevant_family = $this_family;
        print "Family: ", $this_family->description(), " (description score = ", $this_family->description_score(), ")\n";
    }
    print "\n";
}


## Part 3
##########


## Get the tree for this member
my $this_tree = $gene_tree_adaptor->fetch_default_for_Member($gene_member);
print "Tree: ", $this_tree->stable_id, ", ", scalar(@{$this_tree->get_all_Members}), " members\n";

## Part 4
##########

## Compare the contents of the family and the gene tree
sub compare_family_tree {
    my ($fam, $tree) = @_;

    my $in_fam = 0;
    my $in_tree = 0;
    my $in_both = 0;
    my %genes_in_family = ();
    my %genes_in_both = ();
    my %genes_in_tree = ();

    foreach my $gene (@{$fam->get_all_GeneMembers}) {
        $genes_in_family{$gene->stable_id} = 1;
        $in_fam++;
    }

    foreach my $gene (@{$tree->get_all_GeneMembers}) {
        $genes_in_tree{$gene->stable_id} = 1;
        $in_tree++;
        if (exists $genes_in_family{$gene->stable_id}) {
            $genes_in_both{$gene->stable_id} = 1;
            $in_both++;
        }
    }

    my $in_fam_only = $in_fam - $in_both;
    my $in_tree_only = $in_tree - $in_both;

    print "Summary: $in_both in both, $in_fam_only in the family only, $in_tree_only in the tree only\n";
}

compare_family_tree($relevant_family, $this_tree);


## Part 4
##########

## Get the SAFB subtree for the taxon Euteleostomi

my $sarco_subtree = undef;
foreach my $node (@{$this_tree->get_all_nodes}) {
    if (($node->taxonomy_level() eq 'Euteleostomi') and ($node->node_type() eq 'speciation')) {
        my $found_safb = 0;
        foreach my $leaf (@{$node->get_all_leaves}) {
            if ($leaf->gene_member->stable_id eq $gene_member->stable_id) {
                $found_safb = 1;
                last;
            }
        }
        if ($found_safb) {
            # Method to speed-up the further calls
            Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($reg->get_adaptor("Multi", "compara", "DnaFrag"), $node->get_all_leaves);
            $sarco_subtree = $node;
            print "The subtree is: ";
            $node->print_node;
            $node->print_tree;
            compare_family_tree($relevant_family, $node->get_AlignedMemberSet);
        }
    }
}


## Part 5
##########

## In the subtree, list the duplications and their confidence score

foreach my $node (@{$sarco_subtree->get_all_nodes}) {
    if ((not $node->is_leaf()) and ($node->node_type eq 'duplication')) {
        print "Found a duplication at ".$node->taxonomy_level()." with a score of ".$node->duplication_confidence_score."\n";
    }
}


## Part 6
##########

## For each species in the subtree, get the closest orthologue to SAFB

my %species;
foreach my $leaf (@{$sarco_subtree->get_all_leaves}) {
    # NOTE: It seems that $species{$leaf->taxonomy_level()} generates a lot more trips to the database
    $species{$leaf->species_tree_node->genome_db->name} = 1;
}

foreach my $species_name (keys %species) {
    # NOTE: If we skip the last argument we would also fetch human paralogues
    my $all_orthologies = $homology_adaptor->fetch_all_by_Member($gene_member, -TARGET_SPECIES => $species_name, -METHOD_LINK_TYPE => 'ENSEMBL_ORTHOLOGUES');
    print $species_name, ": ", scalar(@{$all_orthologies}). " orthologues\n";

    # Method to speed-up the further calls
    Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($reg->get_adaptor("Multi", "compara", "AlignedMember"), $all_orthologies);

    my $best_id = 0;
    my $best_orthologue = undef;
    foreach my $orthology (@$all_orthologies) {
        # In the homology pair, the first gene is the query gene (SAFB), and the second is the target gene (in $species_name)
        my $orthologue = $orthology->get_all_Members->[1];
        if ($orthologue->perc_id > $best_id) {
            $best_id = $orthologue->perc_id;
            $best_orthologue = $orthologue;
        }
    }
    if ($best_orthologue) {
        print " > The closest has $best_id % of identity, and is: ", $best_orthologue->toString(), "\n";
    }
}

