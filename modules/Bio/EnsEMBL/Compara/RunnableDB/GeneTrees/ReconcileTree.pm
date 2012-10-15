=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ReconcileTree

=cut

=head1 DESCRIPTION

This Runnable will run treebest on a tree to reconcile it with
the species tree. Information about lost taxa and speciation /
duplication events are then stored.
The tree topology is not changed.

This module is currently not used in any pipeline.

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ReconcileTree;

use strict;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


###########################
# eHive inherited methods #
###########################

sub param_defaults {
    return {
        # Which tags are we updating ?
        'store_lost_taxon_id'   => 1,
        'store_node_type'       => 1,
    }
}


sub fetch_input {
    my $self = shift @_;

    my $gene_tree_id = $self->param('gene_tree_id') or die "'gene_tree_id' is an obligatory parameter";
    my $gene_tree    = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID( $gene_tree_id )
                                        or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    $gene_tree->preload();
    $gene_tree->print_tree(10) if $self->debug;

    $self->param('gene_tree', $gene_tree->root);
}

sub run {
    my $self = shift;

    $self->run_treebest_sdi;
    $self->map_nodes('gene_tree', 'ini_nodes');
    $self->map_nodes('new_tree', 'new_nodes');
}

sub write_output {
    my $self = shift;

    $self->write_tags();
}

sub post_cleanup {
    my $self = shift;

    $self->param('gene_tree')->release_tree;
    $self->param('new_tree')->release_tree;
}


####################
# Internal methods #
####################

sub run_treebest_sdi {
    my $self = shift;

    my $tree = $self->param('gene_tree');
    my $tree_str = $tree->newick_format('member_id_taxon_id');

    #parse newick into a new tree object structure
    my $newick = $self->run_treebest_sdi($tree_str, 0);
    my $newroot = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, 'Bio::EnsEMBL::Compara::GeneTreeNode');
    $newroot->print_tree(20) if($self->debug > 1);
    $self->param('new_tree', $newroot);
}


# Convenience method to call _do_map
#
sub map_nodes {
    my $self = shift;
    my $tree = $self->param(shift);
    my $hash = $self->param(shift, {});
    _do_map($tree, $hash);
    print join("\n", keys %$hash), "\n\n\n" if $self->debug;
}


# Recursively stores in the hash the nodes, based on their position in the tree
#
sub _do_map {
    my $node = shift;
    my $hash = shift;
    my $name;
    if ($node->is_leaf) {
        # Get the member_id
        if ($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
            # DB tree
            $name = $node->member_id;
        } else {
            # Treebest tree
            $node->name =~ /^([0-9]*)_/;
            $name = $1;
        }
    } else {
        # Concatenate the member_ids
        my @names;
        foreach my $child (@{$node->children}) {
            push @names, _do_map($child, $hash);
        }
        $name = join('/', sort @names);
    }
    $hash->{$name} = $node;
    return $name;
}


# Write all the "lost_taxon_id" and "node_type" tags
#
sub write_tags {
    my $self = shift;

    foreach my $name (keys %{$self->param('ini_nodes')}) {

        # Checks that the two hashes exactly have the same set of keys
        die if not exists $self->param('new_nodes')->{$name};
        my $node = $self->param('new_nodes')->{$name};
        delete $self->param('new_nodes')->{$name};

        my $old_node = $self->param('ini_nodes')->{$name};
        print Dumper($node->get_tagvalue_hash) if $self->debug;

        if ($self->param('store_lost_taxon_id')) {
            $old_node->delete_tag('lost_taxon_id');
            if ($node->has_tag('E')) {
                my $n_lost = $node->get_tagvalue('E');
                $n_lost =~ s/.{2}//;        # get rid of the initial $-
                my @lost_taxa = split('-', $n_lost);
                foreach my $taxon (@lost_taxa) {
                    if ($self->debug) {
                        printf("store lost_taxon_id : $taxon "); $node->print_node;
                    }
                    $old_node->store_tag('lost_taxon_id', $taxon, 1);
                }
            }
        }

        if ($self->param('store_node_type')) {
            if ($node->get_child_count) {
                my $node_type = '';
                if ($node->get_tagvalue("DD", 0)) {
                    $node_type = 'dubious';
                } elsif ($node->get_tagvalue('Duplication', '') eq '1') {
                    $node_type = ($old_node->get_tagvalue('node_type') eq 'gene_split' ? 'gene_split' : 'duplication');
                } else {
                    $node_type = 'speciation';
                }
                $old_node->store_tag('node_type', $node_type);
                if ($self->debug) {
                    print "store node_type: $node_type"; $node->print_node;
                }
            } else {
                $old_node->delete_tag('node_type');
            }
        }
    }

    # Checks that the two hashes exactly have the same set of keys
    die if scalar(keys %{$self->param('new_nodes')});
}

1;
