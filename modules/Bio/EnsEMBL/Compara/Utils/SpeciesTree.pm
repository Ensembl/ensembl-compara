=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use LWP::Simple;
use URI::Escape;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::SpeciesTreeNode;

=head2 create_species_tree

    Create a taxonomy tree from original NCBI taxonomy tree by only using a subset of taxa (provided either as a list or species_set or all_genome_dbs)

=cut

sub create_species_tree {
    my ($self, @args) = @_;

    my ($compara_dba, $no_previous, $species_set, $extrataxon_sequenced, $multifurcation_deletes_node, $multifurcation_deletes_all_subnodes, $return_ncbi_tree) =
        rearrange([qw(COMPARA_DBA NO_PREVIOUS SPECIES_SET EXTRATAXON_SEQUENCED MULTIFURCATION_DELETES_NODE MULTIFURCATION_DELETES_ALL_SUBNODES RETURN_NCBI_TREE)], @args);

    my $taxon_adaptor = $compara_dba->get_NCBITaxonAdaptor;
    $taxon_adaptor->_id_cache->clear_cache();

    my $root;
    my %taxa_for_tree = ();
    my %gdbs_by_taxon_id = ();

        # loading the initial set of taxa from genome_db:
    if(!$no_previous or $species_set) {

        my $gdb_list = $species_set ? $species_set->genome_dbs() : $compara_dba->get_GenomeDBAdaptor->fetch_all();

        # Identify the genome components that have their principal GenomeDB in the list
        my %principal_gdbs = map {$_->dbID => 1} grep {$_->taxon_id and $_->is_polyploid} @$gdb_list;
        my %component_gdbs = map {$_->dbID => 1} grep {$_->taxon_id and $_->genome_component and $principal_gdbs{$_->principal_genome_db->dbID}} @$gdb_list;

        foreach my $gdb (@$gdb_list) {
            if ($component_gdbs{$gdb->dbID}) {
                # This is the component of a polyploid genome that is
                # in the list. Expand it later
                push @{$gdbs_by_taxon_id{$gdb->taxon_id}}, $gdb;
                warn $gdb->dbID, " is the component ", $gdb->genome_component;
                next;
            }
            my $taxon_id = $gdb->taxon_id;
            next unless $taxon_id;
            if ($taxa_for_tree{$taxon_id}) {
                my $ogdb = $compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($taxa_for_tree{$taxon_id}->{_gdb_id_for_cast});
                warn sprintf("GenomeDB %d (%s) and %d (%s) have the same taxon_id: %d\n", $gdb->dbID, $gdb->name, $ogdb->dbID, $ogdb->name, $taxon_id);
                next;
            }
            my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($taxon_id);
            $taxon->{_gdb_id_for_cast} = $gdb->dbID;
            $taxa_for_tree{$taxon_id} = $taxon;
        }
    }

        # loading from extrataxon_sequenced:
    foreach my $extra_taxon (@$extrataxon_sequenced) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        throw("Unknown taxon_id '$extra_taxon'") unless $taxon;
        if ($taxa_for_tree{$extra_taxon}) {
            warn $taxon->name, " is already in the tree\n";
            next;
        }
        $taxa_for_tree{$extra_taxon} = $taxon;
    }


    # build the tree
    foreach my $taxon (values %taxa_for_tree) {
        $taxon->no_autoload_children;
        if (not $root) {
            $root = $taxon->root;
            next;
        }
        my $n1 = scalar(@{$root->get_all_leaves});
        $root->merge_node_via_shared_ancestor($taxon);
        my $n2 = scalar(@{$root->get_all_leaves});
        if ($n1 != ($n2-1)) {
            my @anc = grep {$taxa_for_tree{$_->node_id}} @{$taxon->get_all_ancestors};
            if (@anc) {
                throw(sprintf('Cannot add %s because an ancestral node (%s) is already in the tree', $taxon->name, $anc[0]->name));
            } else {
                throw(sprintf('Cannot add %s because a descendant (%s) is already in the tree', $taxon->name, $taxon->get_all_leaves->[0]->name));
            }
        }
    }

    $root = $root->minimize_tree if (defined($root));

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
    @subnodes = $root->get_all_subnodes;
    foreach my $extra_taxon (@$multifurcation_deletes_all_subnodes) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        my $taxon_name = $taxon->name;
        my $taxon_id = $taxon->taxon_id;
        my $node_in_root = $root->find_node_by_node_id($taxon_id);
        foreach my $node ($node_in_root->get_all_subnodes) {
            next if ($node->is_leaf);
            my $node_children = $node->children;
            foreach my $child (@$node_children) {
                $node->parent->add_child($child);
            }
            $node->disavow_parent;
        }
    }

    return $root if $return_ncbi_tree;

    my $stn_root = $root->adaptor->db->get_SpeciesTreeNodeAdaptor->new_from_NestedSet($root);

    # We need to duplicate all the taxa that are supposed in several copies (several genome_dbs sharing the same taxon_id)
    # Currently, we only do that for component GenomeDBs
    foreach my $taxon_id (keys %gdbs_by_taxon_id) {
        my $current_nodes = $stn_root->find_nodes_by_field_value('taxon_id', $taxon_id);
        throw("There should exactly 1 node with taxon_id $taxon_id") if scalar(@$current_nodes) != 1;
        my $current_leaf = $current_nodes->[0];
        my $new_node = $current_leaf->copy();
        $new_node->_complete_cast_node($current_leaf);
        $new_node->node_id($taxon_id);
        $current_leaf->parent->add_child($new_node);
        $new_node->add_child($current_leaf);
        foreach my $genome_db (@{$gdbs_by_taxon_id{$taxon_id}}) {
            my $new_leaf = $current_leaf->copy();
            $new_leaf->_complete_cast_node($current_leaf);
            $new_leaf->genome_db_id($genome_db->dbID);
            $new_leaf->node_id($taxon_id);
            $new_leaf->node_name(sprintf('%s (component %s)', $new_leaf->node_name, $genome_db->genome_component)) if $genome_db->genome_component;
            $new_node->add_child($new_leaf);
        }
    }

    return $stn_root;
}


=head2 prune_tree

    Only retain the leaves that belong to the species_set

=cut

sub prune_tree {
    my ($self, $input_tree, $compara_dba, $species_set_id) = @_;

    my $gdb_list = $species_set_id
        ? $compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)->genome_dbs()
        : $compara_dba->get_GenomeDBAdaptor->fetch_all;

    my %leaves_names = map { ($_ => 1) } grep { !/ancestral/ } map { lc($_->name) } @$gdb_list;

    foreach my $leaf (@{$input_tree->get_all_leaves}) {
        unless ($leaves_names{lc($leaf->name)}) {
            #print $leaf->name," leaf disavowing parent\n";
            $leaf->disavow_parent;
            $input_tree = $input_tree->minimize_tree;
        }
    }

    return $input_tree;
}


=head2 get_timetree_estimate

    Web scraping of the divergence of two taxa from the timetree.org resource.
    Currently used to get the divergence of a new Ensembl species (see place_species.pl)
    Do not use this method for large-scale data-mining

=cut

sub get_timetree_estimate {
    my ($self, $node) = @_;

    assert_ref($node, 'Bio::EnsEMBL::Compara::SpeciesTreeNode');
    return if $node->is_leaf();
    my @children = @{$node->children};
    if (scalar(@children) == 1) {
        warn sprintf("'%s' has a single child. Cannot estimate the divergence time of a *single* species.\n", $node->name);
        return;
    }

    my $url_template = 'http://www.timetree.org/search/pairwise/%s/%s';
    my $last_page;

    # For multifurcations, if a comparison fails, we can still try the other ones
    while (my $child1 = shift @children) {
        foreach my $child2 (@children) {
            my $url = sprintf($url_template, uri_escape($child1->get_all_leaves()->[0]->node_name), uri_escape($child2->get_all_leaves()->[0]->node_name));
            my $timetree_page = get($url);
            $timetree_page =~ /<h1 style="margin-bottom: 0px;">(.*)<\/h1> Million Years Ago/;
            return $1 if $1;
            $last_page = $url;
        }
    }
    warn sprintf("Could not get a valid answer from timetree.org for '%s' (see %s).\n", $node->name, $last_page);
    return;
}

1;
