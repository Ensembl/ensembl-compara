
=pod

=head1 NAME

    Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor

=head1 SYNOPSIS

    my $species_tree = $compara_dba->get_SpeciesTreeAdaptor->create_species_tree();                                         # include all available species from genome_db by default

    my $species_tree = $compara_dba->get_SpeciesTreeAdaptor->create_species_tree( -species_set_id => 12345 );               # only use the species from given species_set

    my $species_tree = $compara_dba->get_SpeciesTreeAdaptor->create_species_tree( -param1 => value1, -param2 => value2 );   # more complex scenarios

=head1 DESCRIPTION

    This is not strictly a DBSQL adaptor, because there is no corresponding DB-persistent object type.
    This module encapsulates functionality to create/manipulate species trees in the form of subroutines
    ( and so the code should be easier to reuse than that in ensembl-compara/scripts/tree ).

=cut


package Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::NestedSet;

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor');


=head2 create_species_tree

    Create a taxonomy tree from original NCBI taxonomy tree by only using a subset of taxa (provided either as a list or species_set or all_genome_dbs)

=cut

sub create_species_tree {
    my ($self, @args) = @_;

    my ($no_previous, $species_set_id, $extrataxon_sequenced, $extrataxon_incomplete, $multifurcation_deletes_node, $multifurcation_deletes_all_subnodes) =
        rearrange([qw(NO_PREVIOUS SPECIES_SET_ID EXTRATAXON_SEQUENCED EXTRATAXON_INCOMPLETE MULTIFURCATION_DELETES_NODE MULTIFURCATION_DELETES_ALL_SUBNODES)], @args);

    my $compara_dba = $self->db();

    my $taxon_adaptor = $compara_dba->get_NCBITaxonAdaptor;
    my $root;

        # loading the initial set of taxa from genome_db:
    if(!$no_previous or $species_set_id) {
        
        my $gdb_list = $species_set_id
            ? $compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)->genome_dbs()
            : $compara_dba->get_GenomeDBAdaptor->fetch_all;

        foreach my $gdb (@$gdb_list) {
            my $taxon_name = $gdb->name;
            next if ($taxon_name =~ /ncestral/);
            my $taxon_id = $gdb->taxon_id;
            my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($taxon_id);
            $taxon->release_children;

            $root = $taxon->root unless($root);
            $root->merge_node_via_shared_ancestor($taxon);
        }
    }

        # loading from extrataxon_sequenced:
    foreach my $extra_taxon (@$extrataxon_sequenced) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        next unless defined($taxon);
        my $taxon_name = $taxon->name;
        my $taxon_id = $taxon->taxon_id;
        $taxon->release_children;

        $root = $taxon->root unless($root);
        $root->merge_node_via_shared_ancestor($taxon);
    }

        # loading from extrataxon_incomplete:
    foreach my $extra_taxon (@$extrataxon_incomplete) {
        my $taxon = $taxon_adaptor->fetch_node_by_taxon_id($extra_taxon);
        my $taxon_name = $taxon->name;
        my $taxon_id = $taxon->taxon_id;
        $taxon->release_children;

        $root = $taxon->root unless($root);
        $root->merge_node_via_shared_ancestor($taxon);
        $taxon->add_tag('is_incomplete', '1');
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

    return $root;
}


=head2 prune_tree

    Only retain the leaves that belong to the species_set

=cut

sub prune_tree {
    my ($self, $input_tree, $species_set_id) = @_;

    my $compara_dba = $self->db();

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

1;
