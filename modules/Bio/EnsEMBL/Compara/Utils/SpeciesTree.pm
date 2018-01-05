=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Compara::Utils::SpeciesTree

=head1 SYNOPSIS

    my $species_tree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree();                                          # include all available species from genome_db by default

    my $species_tree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree( -species_set => $ss );                     # only use the species from given species_set

    my $species_tree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree ( -param1 => value1, -param2 => value2 );   # more complex scenarios

=head1 DESCRIPTION

    This module encapsulates functionality to create/manipulate species trees in the form of subroutines
    ( and so the code should be easier to reuse than that in ensembl-compara/scripts/tree ).

=head1 NOTE

    This file has been moved from Bio::EnsEMBL::DBSQL::SpeciesTreeAdaptor.

=cut


package Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use strict;
use warnings;

use List::Util qw(max);
use Scalar::Util qw(weaken);

use LWP::Simple;
use URI::Escape;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(:assert :check);
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::SpeciesTreeNode;

=head2 create_species_tree

    Create a taxonomy tree from original NCBI taxonomy tree by only using a subset of taxa (provided either as a list or species_set or all_genome_dbs)

=cut

sub create_species_tree {
    my ($self, @args) = @_;

    my ($compara_dba, $no_previous, $species_set, $extrataxon_sequenced, $multifurcation_deletes_node, $multifurcation_deletes_all_subnodes, $allow_subtaxa, $return_ncbi_tree) =
        rearrange([qw(COMPARA_DBA NO_PREVIOUS SPECIES_SET EXTRATAXON_SEQUENCED MULTIFURCATION_DELETES_NODE MULTIFURCATION_DELETES_ALL_SUBNODES ALLOW_SUBTAXA RETURN_NCBI_TREE)], @args);

    my $taxon_adaptor = $compara_dba->get_NCBITaxonAdaptor;
    $taxon_adaptor->_id_cache->clear_cache();

    my $root;                       # The root of the tree we're building
    my %taxa_for_tree = ();         # taxon_id -> NCBITaxon mapping
    my %ref_gdb_by_taxon_id;        # taxon_id -> first GenomeDB object found for this taxon
    my %extra_gdbs_by_taxon_id;     # taxon_id -> [GenomeDB objects] with the extra GenomeDB to attach

        # loading the initial set of taxa from genome_db:
    if(!$no_previous or $species_set) {

        my $gdb_list = $species_set ? $species_set->genome_dbs() : $compara_dba->get_GenomeDBAdaptor->fetch_all();

        # Process the polyploid genomes first so that:
        #  1) the default name is Triticum aestivum
        #  2) all the components go to %extra_gdbs_by_taxon_id and are added later with the component name added
        my @sorted_gdbs = sort {$b->is_polyploid <=> $a->is_polyploid} @$gdb_list;

        foreach my $gdb (@sorted_gdbs) {
            my $taxon_id = $gdb->taxon_id;
            next unless $taxon_id;

            # If we use $gdb->taxon here we'll alter it and further calls
            # to $gdb->taxon will see the altered version. We take a fresh
            # version instead
            my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($taxon_id);
            next unless $taxon; # unexisting taxon

            # Get the real taxon_id in case the GenomeDB is linked to a retired one
            $taxon_id = $taxon->dbID;

            if ($taxa_for_tree{$taxon_id}) {
                push @{$extra_gdbs_by_taxon_id{$taxon_id}}, $gdb;
                #my $ogdb = $ref_gdb_by_taxon_id{$taxon_id};
                #warn sprintf("GenomeDB %d (%s) and %d (%s) have the same taxon_id: %d\n", $gdb->dbID, $gdb->name, $ogdb->dbID, $ogdb->name, $taxon_id);
                next;
            }
            $ref_gdb_by_taxon_id{$taxon_id} = $gdb;
            $taxa_for_tree{$taxon_id} = $taxon;
        }
    }

        # loading from extrataxon_sequenced:
    foreach my $extra_taxon (@$extrataxon_sequenced) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        throw("Unknown taxon_id '$extra_taxon'") unless $taxon;
        if ($taxa_for_tree{$extra_taxon}) {
            #warn $taxon->name, " is already in the tree\n";
            next;
        }
        $taxa_for_tree{$extra_taxon} = $taxon;
    }

    return undef unless %taxa_for_tree;

    # build the tree taking the parents before the children
    my @previous_right_idx;
    my %node_id_index = ();
    foreach my $taxon (sort {$a->left_index <=> $b->left_index} values %taxa_for_tree) {
        #warn "Adding ", $taxon->toString, "\n";
        $taxon->no_autoload_children;
        if (not $root) {
            $root = $taxon->root;
            $node_id_index{$taxon->dbID} = $taxon;
            $node_id_index{$_->dbID} = $_ for @{$taxon->get_all_ancestors};
            @previous_right_idx = ( $taxon->right_index, $taxon );
            next;
        }

        # Detection of species+subspecies mix
        if ($previous_right_idx[0] > $taxon->left_index) {
            # We're still under the previous taxon
            my $anc = $previous_right_idx[1];
            if ($allow_subtaxa) {
                #warn sprintf('%s will be added later because it is below a node (%s) that is already in the tree', $taxon->name, $anc->name);
                push @{$extra_gdbs_by_taxon_id{$anc->dbID}}, $ref_gdb_by_taxon_id{$taxon->dbID};
                next;
            } else {
                throw(sprintf('Cannot add %s because it is below a node (%s) that is already in the tree', $taxon->name, $anc->name));
            }
        }
        @previous_right_idx = ( $taxon->right_index, $taxon );

        $root->merge_node_via_shared_ancestor($taxon, \%node_id_index);
    }

    $root = $root->minimize_tree;

        # Deleting nodes to further multifurcate:
    my @subnodes = $root->get_all_subnodes;
    foreach my $extra_taxon (@$multifurcation_deletes_node) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        my $taxon_name = $taxon->name;
        my $taxon_id = $taxon->taxon_id;
        foreach my $node (@subnodes) {
            next unless ($node->node_id == $extra_taxon);
            my $node_children = $node->children;
            foreach my $child (@$node_children) {
                $node->parent->add_child($child);
            }
            $node->disavow_parent;
        }
    }

        # Deleting subnodes down to a given node:
    my %taxon_id_to_flatten = ();
    foreach my $extra_taxon (@$multifurcation_deletes_all_subnodes) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        my $taxon_name = $taxon->name;
        my $taxon_id = $taxon->taxon_id;
        my $node_in_root = $root->find_node_by_node_id($taxon_id);
        unless ($node_in_root) {
            warn "Cannot flatten the taxon $taxon_id as it is not found in the tree\n";
            next;
        }
        foreach my $node ($node_in_root->get_all_subnodes) {
            next if ($node->is_leaf);
            my $node_children = $node->children;
            foreach my $child (@$node_children) {
                $node->parent->add_child($child);
                $taxon_id_to_flatten{$child->taxon_id} = 1;
            }
            $node->disavow_parent;
        }
    }

    $taxon_adaptor->_id_cache->clear_cache();

    # Fix the distance_to_parent fields (NCBITaxonAdaptor sets them to 0.1)
    $root->distance_to_parent(0);                           # NULL would be more accurate
    $_->distance_to_parent(1) for $root->get_all_subnodes;  # Convention

    return $root if $return_ncbi_tree;

    my $stn_root = $root->copy('Bio::EnsEMBL::Compara::SpeciesTreeNode', $compara_dba->get_SpeciesTreeNodeAdaptor);
    $root->release_tree;

    my %leaf_by_taxon_id;
    foreach my $leaf (@{$stn_root->get_all_leaves}) {
        $leaf_by_taxon_id{$leaf->taxon_id} = $leaf;
        if (my $gdb = $ref_gdb_by_taxon_id{$leaf->taxon_id}) {
            $leaf->{'_genome_db'} = $gdb;
            $leaf->{'_genome_db_id'} = $gdb->dbID;
            weaken($leaf->{'_genome_db'});
            $leaf->node_name($gdb->get_scientific_name('unique'));
        }
    }

    # We need to duplicate all the taxa that are supposed in several copies (several genome_dbs sharing the same taxon_id)
    # Currently, we only do that for component GenomeDBs
    foreach my $taxon_id (keys %extra_gdbs_by_taxon_id) {
        my $current_leaf = $leaf_by_taxon_id{$taxon_id} or
                            throw("Could not find the leaf with taxon_id $taxon_id");
        my $new_node = $current_leaf->copy_node();
        $new_node->node_id($taxon_id);
        $current_leaf->parent->add_child($new_node);
        $new_node->add_child($current_leaf);
        $new_node->{'_genome_db_id'} = undef;
        $new_node->name($current_leaf->taxon->name);
        foreach my $genome_db (@{$extra_gdbs_by_taxon_id{$taxon_id}}) {
            my $new_leaf = $current_leaf->copy_node();
            $new_leaf->genome_db_id($genome_db->dbID);
            $new_leaf->{'_genome_db'} = $genome_db;
            $new_leaf->node_id($taxon_id);
            $new_leaf->node_name($genome_db->get_scientific_name('unique'));
            $new_node->add_child($new_leaf);
            if ($genome_db->taxon_id != $taxon_id) {
                $new_leaf->taxon_id($genome_db->taxon_id);
                $new_leaf->node_name($genome_db->taxon->name);
            }
        }
        # If a parent node of this species has been flattened by a
        # multifurcation_deletes_all_subnodes flag, we need to keep it flat
        if ($taxon_id_to_flatten{$taxon_id}) {
            $new_node->print_node;
            my $anchor_node = $new_node->parent;
            my $leaves = $new_node->children;
            $anchor_node->add_child($_) for @$leaves;
            $new_node->disavow_parent;
        }
    }

    return $stn_root;
}


=head2 new_from_newick

    Build a species tree from a newick of GenomeDB production names

=cut

sub new_from_newick {
    my ($self, $newick, $compara_dba) = @_;

    my $species_tree_root = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $newick, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' );
    $species_tree_root = $species_tree_root->minimize_tree;     # The user-defined trees may have some 1-child nodes

    # Let's try to find genome_dbs and ncbi taxa
    my $gdb_a = $compara_dba->get_GenomeDBAdaptor;

    # We need to build a hash locally because # $gdb_a->fetch_by_name_assembly()
    # doesn't return non-default assemblies, which can be the case !
    my %all_genome_dbs = map {(lc $_->name) => $_} (grep {not $_->genome_component} @{$gdb_a->fetch_all});

    # First, we remove the extra species that the tree may contain
    foreach my $node (@{$species_tree_root->get_all_leaves}) {
        my $gdb = $all_genome_dbs{lc $node->name};
        if ((not $gdb) and ($node->name =~ m/^(.*)_([^_]*)$/)) {
            # Perhaps the node represents the component of a polyploid genome
            my $pgdb = $all_genome_dbs{lc $1};
            if ($pgdb and $pgdb->is_polyploid) {
                $gdb = $pgdb->component_genome_dbs($2) or die "No component named '$2' in '$1'\n";
            }
        }
        if ($gdb) {
            $node->genome_db_id($gdb->dbID);
            $node->taxon_id($gdb->taxon_id);
            $node->node_name($gdb->get_scientific_name('unique'));
            $node->{_tmp_gdb} = $gdb;
        } else {
            warn $node->name, " not found in the genome_db table";
            unless ($node->has_parent) {
                # Not a single leaf is found in the genome_db table
                return undef;
            }
            $node->disavow_parent();
            $species_tree_root = $species_tree_root->minimize_tree;
        }
    }

    # Secondly, we can search the LCAs in the NCBI tree
    my $ncbi_taxa_a = $compara_dba->get_NCBITaxonAdaptor;
    $ncbi_taxa_a->_id_cache->clear_cache();
    $species_tree_root->traverse_tree_get_all_leaves( sub {
            my ($node, $leaves) = @_;
            my $int_taxon = $ncbi_taxa_a->fetch_first_shared_ancestor_indexed(map {$_->{_tmp_gdb}->taxon} @$leaves);
            $node->taxon_id($int_taxon->taxon_id);
            $node->node_name($int_taxon->name) unless $node->name;
        } );

    return $species_tree_root;
}


=head2 prune_tree

    Only retain the leaves that belong to the species_set

=cut

sub prune_tree {
    my ($self, $input_tree, $compara_dba, $species_set_id) = @_;

    my $gdb_list = $species_set_id
        ? $compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)->genome_dbs()
        : $compara_dba->get_GenomeDBAdaptor->fetch_all;

    my %leaves_names = map { (lc $_->name => $_) } grep { $_->name !~ /ancestral/i } @$gdb_list;

    foreach my $leaf (@{$input_tree->get_all_leaves}) {
        if ($leaf->genome_db_id and $leaves_names{lc($leaf->genome_db->name)}) {
            # Match by genome_db_id: nothing to do
        } elsif ($leaves_names{lc($leaf->name)}) {
            # Match by name: fill in the other fields
            $leaf->genome_db_id( $leaves_names{lc($leaf->name)}->dbID );
            $leaf->taxon_id( $leaves_names{lc($leaf->name)}->taxon_id );
        } elsif ($leaf->has_parent) {
            # No match: disconnect the leaf
            #print $leaf->name," leaf disavowing parent\n";
            $leaf->disavow_parent;
            $input_tree = $input_tree->minimize_tree;
        } else {
            # We've removed everything in the tree
            return undef;
        }
    }

    return $input_tree;
}


=head2 get_timetree_estimate_for_node

    Web scraping of the divergence of two taxa from the timetree.org resource.
    Currently used to get the divergence of a new Ensembl species (see place_species.pl)
    Do not use this method for large-scale data-mining

=cut

sub get_timetree_estimate_for_node {
    my ($self, $node) = @_;

    check_ref($node, 'Bio::EnsEMBL::Compara::NCBITaxon', 'node') or
        assert_ref($node, 'Bio::EnsEMBL::Compara::SpeciesTreeNode', 'node');

    return 0 if $node->is_leaf();
    my @children = @{$node->children};
    if (scalar(@children) == 1) {
        warn sprintf("'%s' has a single child. Cannot estimate the divergence time of a non-furcating node.\n", $node->name);
        return;
    }

    my $url_template = 'http://www.timetree.org/search/pairwise/%s/%s';
    my $last_page;

    # For multifurcations, if a comparison fails, we can still try the other ones
    while (my $child1 = shift @children) {
        foreach my $child2 (@children) {
            next unless $child1->taxon_id && $child2->taxon_id;
            return 0 if $child1->taxon_id == $child2->taxon_id;
            my $child1_rep = $child1->get_all_leaves()->[0];
            my $child2_rep = $child2->get_all_leaves()->[0];
            # We might need to do this if TimeTree doesn't return consistent data for all possible pairs of children
            #foreach my $child1_rep (@{$child1->get_all_leaves()}) {
                #foreach my $child2_rep (@{$child2->get_all_leaves()}) {
                    #next unless $child1_rep->taxon_id && $child2_rep->taxon_id;
                    #return 0 if $child1_rep->taxon_id == $child2_rep->taxon_id;
            my $child1_name = $child1_rep->isa('Bio::EnsEMBL::Compara::NCBITaxon') ? $child1_rep->name : $child1_rep->taxon->name;
            my $child2_name = $child2_rep->isa('Bio::EnsEMBL::Compara::NCBITaxon') ? $child2_rep->name : $child2_rep->taxon->name;
            my $url = sprintf($url_template, uri_escape($child1_name), uri_escape($child2_name));
            $last_page = $url;
            my $timetree_page = get($url);
            next unless $timetree_page;
            $timetree_page =~ /<h1 style="margin-bottom: 0px;">(.*)<\/h1> Million Years Ago/;
            return $1 if $1;
                #}
            #}
        }
    }
    if ($last_page) {
        warn sprintf("Could not get a valid answer from timetree.org for '%s' (see %s).\n", $node->name, $last_page);
    } else {
        warn sprintf("The taxon_ids of '%s' and its children do not allow querying TimeTree.\n", $node->name);
    }
    return;
}


=head2 interpolate_timetree

    Function to compute the missing divergence times, by interpolating (or
    extrapolating) from the existing data

=cut

sub interpolate_timetree {
    my $root = shift;
    my @subnodes = $root->get_all_subnodes;
    unless ($root->has_divergence_time) {
        my @data;
        # For Opisthokonta, average_height gives a more accurate estimate
        # than max_distance
        foreach my $node (@subnodes) {
            if ($node->has_divergence_time) {
                my $h = $node->average_height or next;
                push @data, $node->get_divergence_time / $h;
            }
        }
        unless (@data) {
            die "Need at least 1 data-point to extrapolate divergence times\n";
        }
        @data = sort {$a <=> $b} @data;
        my $median_ratio = $data[int(scalar(@data)/2)];
        my $root_height = $root->average_height * $median_ratio;
        print "Setting root mya to $root_height\n";
        $root->set_divergence_time($root_height);
    }
    foreach my $node (@subnodes) {
        if ($node->has_divergence_time and not $node->parent->has_divergence_time) {
            # Find an ancestor with data. This is guaranteed to end since
            # we've ensured that the root node has data
            my $good_parent = $node;
            my $total_length = 0;
            do {
                $total_length += $good_parent->distance_to_parent;
                $good_parent = $good_parent->parent;
            } until ($good_parent->has_divergence_time);
            print "Interpolating values between ", $node->name, " and ", $good_parent->name, "\n";
            my $ratio = ($good_parent->get_divergence_time - $node->get_divergence_time) / $total_length;
            my $cur_node = $node;
            my $interpolated_timetree = $node->get_divergence_time;
            do {
                $interpolated_timetree += $cur_node->distance_to_parent * $ratio;
                $cur_node = $cur_node->parent;
                print "Setting ", $cur_node->taxon->name, " = $interpolated_timetree mya\n";
                $cur_node->set_divergence_time($interpolated_timetree);
            } until ($cur_node->parent->has_divergence_time);
        }
    }
    # Find subtrees that completely miss TimeTree data
    foreach my $leaf (@subnodes) {
        next if !$leaf->is_leaf;
        next if $leaf->parent->has_divergence_time;
        my $root_missing_data = $leaf;
        do {
            $root_missing_data = $root_missing_data->parent;
        } until ($root_missing_data->parent->has_divergence_time);
        print "Interpolating values under ", $root_missing_data->name, " (found from ", $leaf->name, ")\n";
        my @todo = ([$root_missing_data, $root_missing_data->parent->get_divergence_time]);
        while (@todo) {
            my ($node, $parent_height) = @{shift @todo};
            next if $node->is_leaf;
            # This will ultrametrize and scale at the same time
            my $child_ratio = $parent_height / ($node->distance_to_parent + $node->max_distance);
            my $interpolated_timetree = $parent_height - $node->distance_to_parent * $child_ratio;
            print "Setting ", $node->taxon->name, " = $interpolated_timetree mya\n";
            $node->set_divergence_time($interpolated_timetree);
            push @todo, map {[$_, $interpolated_timetree]} @{$node->children};
        }
    }
}


=head2 ultrametrize_from_timetree

    Function to compute all the branch lengths from the TimeTree divergence times.
    It also fixes the TimeTree data to make them monotonous (i.e. avoid negative branches)

=cut

sub ultrametrize_from_timetree {
    my $node = shift;

    return [0, $node] if $node->is_leaf;

    my @children_data;
    foreach my $child (@{$node->children}) {
        push @children_data, ultrametrize_from_timetree($child);
    }
    my $t = max(map {$_->[0]} @children_data);

    # We make the parents as old as needed to go over their children
    if (!$node->has_divergence_time or ($node->get_divergence_time <= $t)) {
        $t += 0.1;  # We work by increments of 0.1
        printf("Shifting %s (%d): %s -> %s mya\n", $node->node_name, $node->node_id, $node->get_divergence_time || 'N/A', $t);
    } else {
        $t = $node->get_divergence_time;
    }

    $_->[1]->distance_to_parent(sprintf("%.0f", 10*($t - $_->[0]))) for @children_data;

    return [$t, $node];
}


=head2 set_branch_lengths_from_gene_trees

    Function to extract all the branch lengths from a set of gene-trees and
    assign lengths to the branches of a species-tree .

=cut

sub set_branch_lengths_from_gene_trees {
    my ($species_tree_root, $gene_trees) = @_;

    # Analyze all the trees
    my %distances = ();
    foreach my $gt (@$gene_trees) {
        my $was_preloaded = $gt->{_preloaded};
        $gt->preload;
        _extract_branch_lengths($gt->root, \%distances);
        $gt->release_tree() unless $was_preloaded;
    }

    # To avoid zeros
    my $epsilon = 0.0001;
    # Get the median value for each species-tree branch
    foreach my $node ($species_tree_root->get_all_subnodes) {
        unless ($distances{$node->node_id}) {
            warn "no branch-length data for ", $node->toString, "\n";
            next;
        }
        my @allval = sort {$a <=> $b} @{$distances{$node->node_id}};
        my $median = $allval[int(scalar(@allval)/2)];
        $node->distance_to_parent( $median || $epsilon );
    }
    _fix_root_distance($species_tree_root);
}


# Recursive method to extract the branch lengths of a gene-tree
# It only considers the branches that are strictly between speciation nodes
sub _extract_branch_lengths {
    my ($gene_tree_node, $distances) = @_;

    return if $gene_tree_node->is_leaf;
    _extract_branch_lengths($_, $distances) for @{$gene_tree_node->children};

    # Take the distances between speciation nodes, without any missing species-tree nodes
    if ($gene_tree_node->node_type eq 'speciation') {
        foreach my $child (@{$gene_tree_node->children})  {
            if ($child->is_leaf || ($child->node_type eq 'speciation')) {
                if ($child->species_tree_node->_parent_id == $gene_tree_node->_species_tree_node_id) {
                    push @{$distances->{$child->_species_tree_node_id}}, $child->distance_to_parent;
                }
            }
        }
    }
}


# Because of the way Treebest computes branch-lengths and the way we
# extract branch-lengths from gene-trees, Opisthokonta -> Bilateria is 0,
# but really this is an issue about rooting the branch.
# Here we rebalance the root in order to align the Bilateria leaves to
# S. cerevisiae
sub _fix_root_distance {
    my $species_tree_root = shift;
    my @children_data;
    my $sum_branches = 0;
    my $children = $species_tree_root->children;
    foreach my $child (@$children) {
        my $h = $child->average_height;
        push @children_data, [$child, $h];
        $sum_branches += $child->distance_to_parent + $h;
    }
    my $avg_branch = $sum_branches / scalar(@$children);
    foreach my $a (@children_data) {
        $a->[0]->distance_to_parent( max($avg_branch - $a->[1], 0) );
    }
}


=head2 ultrametrize_from_branch_lengths

    Function to make the tree ultrametric. It is based on the average height of
    each sub-tree, which works better visually than max_distance

=cut

sub ultrametrize_from_branch_lengths {
    my ($node, $node_ratio) = @_;

    return 0 if $node->is_leaf;

    my $n_decimals = 4;
    my $min_branch_length = "1e-$n_decimals";

    # Target height for $node
    my $node_height = $node->average_height * ($node_ratio // 1);
    my @children_data;
    foreach my $child (@{$node->children}) {
        unless ($child->distance_to_parent + $child->average_height) {
            # Avoid dealing with 0s
            $_->distance_to_parent($min_branch_length) for @{$child->get_all_nodes};
        }
        # Rescale the child's sub-tree and query its height
        my $child_ratio = $node_height / ($child->distance_to_parent + $child->average_height);
        my $child_branch = max($min_branch_length, $child->distance_to_parent * $child_ratio);
        my $child_height = ultrametrize_from_branch_lengths($child, $child_ratio);
        push @children_data, [$child_height + $child_branch, $child_height, $child];
    }
    # Get the height of $node as constrained by the children and their sub-trees
    $node_height = sprintf("%.${n_decimals}f", max(map {$_->[0]} @children_data));
    die "Rounding errors" unless $node_height;

    # Set the distances according to $node_height (none should be zero)
    foreach my $a (@children_data) {
        # Final branch as an integer with $n_decimals significant digits
        my $child_branch = sprintf("%.0f", "1e$n_decimals" * ($node_height - $a->[1]));
        die "Rounding errors" unless $child_branch;
        $a->[2]->distance_to_parent($child_branch);;
    }
    return $node_height;
}


=head2 binarize_multifurcation_using_gene_trees

    Function to binarize a multifurcation by selecting the most frequent
    topology out of a set of gene-trees

=cut

sub binarize_multifurcation_using_gene_trees {
    my ($species_tree_node, $gene_trees) = @_;

    # Lookup tables
    my %stn_id_2_child = ();
    my %stn_id_2_stn = ();
    my $n_child = 0;
    foreach my $child (@{$species_tree_node->children}) {
        $stn_id_2_stn{$child->node_id} = $child;
        $n_child++;
        foreach my $leaf (@{$child->get_all_nodes}) {
            $stn_id_2_child{$leaf->node_id} = $child->node_id;
        }
    }

    # Nothing to do if the node is not a multifurcation
    return if $n_child < 3;

    # Analyze all the trees
    my %counts = ();
    foreach my $gt (@$gene_trees) {
        my $was_preloaded = $gt->{_preloaded};
        $gt->preload;
        my $s = _count_topologies($gt->root, $species_tree_node->node_id, \%stn_id_2_child, \%counts);
        $counts{$s}++ if $s;
        $gt->release_tree() unless $was_preloaded;
    }

    # sort the complete counts and take the highest one
    my ($best_topology) = sort {$counts{$b} <=> $counts{$a}}
                          grep {$n_child-1 == (my $this_count = () = $_ =~ /\(/g)}
                          keys %counts;
    unless ($best_topology) {
        die "No topology found for ", $species_tree_node->node_name;
    }

    # Make a tree of SpeciesTreeNode objects from the Newick tree
    my $internal_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $best_topology, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' );
    # Give all the internal names the taxon information of the query node (the multifurcation)
    foreach my $node (@{$internal_tree->get_all_nodes}) {
        next if $node->is_leaf;
        $node->node_id(undef);
        $node->adaptor($species_tree_node->adaptor);
        $node->taxon_id($species_tree_node->taxon_id);
        $node->node_name($species_tree_node->node_name);
    }
    # Replace each leaf of the partial tree with the full sub-tree
    foreach my $leaf (@{$internal_tree->get_all_leaves}) {
        #print $leaf->name, "\n";
        my $orig_stn = $stn_id_2_stn{$leaf->name};
        $leaf->parent->add_child($orig_stn, $orig_stn->distance_to_parent);
        $leaf->disavow_parent;
    }
    # Replace the root of the partial tree with the query node
    $species_tree_node->add_child($_, 0) for @{$internal_tree->children};
}


# The return value is the newick string with the tree topology
# It selects all the sub-trees that link $ref_stn_id to its children
#  and prints the topology
sub _count_topologies {
    my ($gene_tree_node, $ref_stn_id, $stn_id_2_child, $counts) = @_;

    if ($stn_id_2_child->{$gene_tree_node->_species_tree_node_id}) {
        return sprintf('%d', $stn_id_2_child->{$gene_tree_node->_species_tree_node_id});
    }

    unless ($gene_tree_node->is_leaf()) {
        # If the current gene_tree_node is $internal_taxon_id speciation and if all the children are fine
        my @child_strings = (map {_count_topologies($_, $ref_stn_id, $stn_id_2_child, $counts)} @{$gene_tree_node->children});
        if ($gene_tree_node->_species_tree_node_id == $ref_stn_id and ($gene_tree_node->node_type eq 'speciation')) {
            if (not grep {not defined $_} @child_strings) {
                return sprintf('(%s,%s)', sort @child_strings);
            }
        }
        # The current node is not good enough, but we still have to register the sub-nodes
        $counts->{$_}++ for grep {defined $_} @child_strings;
    }
    # undef means that the gene-tree node is in a different part of the species-tree or
    # something prevents an accurate prediction (duplication nodes, etc)
    return undef;
}

=head2 collapse_short_branches

    Arg [1] : root node (Bio::EnsEMBL::Compara::SpeciesTreeNode)
    Arg [2] : optional. threshold for short branches. default: 0.001
    Example : my $collapsed_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree
                        ->collapse_short_branches($species_tree_root, 0.01);
    Description: given a species_tree_node root, collapse all internal branches
                 shorter than $threshold into polytomies
    Returntype: Bio::EnsEMBL::Compara::SpeciesTreeNode - root of new tree

=cut

sub collapse_short_branches {
    my ( $self, $root_node, $threshold ) = @_;
    $threshold ||= 0.001;

    # my $curr_node = $root_node;
    my @node_children = @{ $root_node->children };
    #foreach my $child ( @$node_children ) {
    while ( my $curr_node = shift @node_children ) {
        next if $curr_node->is_leaf;

        my $dist_to_parent = $curr_node->distance_to_parent;
        print "\tdistance_to_parent: $dist_to_parent ( <= $threshold ?)\n";
        print "!!! YES !!!\n" if ($dist_to_parent <= $threshold);
        if ($dist_to_parent <= $threshold) {
            # add children to parent node with updated branch lengths
            foreach my $child ( @{$curr_node->children} ) {
                print "adding child to parent: ";
                $child->print_node();
                my $new_dist = $curr_node->parent->distance_to_node($child);
                $curr_node->parent->add_child($child, $new_dist);
                push( @node_children, $child ) unless $child->is_leaf;
            }
            $curr_node->disavow_parent;
        } else {
            push( @node_children, @{ $curr_node->children } );
        }

        my @str_nodes = map { $_->string_node } @node_children;
        chomp @str_nodes;
        print "str_nodes: " . join(', ', @str_nodes) . "\n";
    }
    return $root_node;
}

1;
