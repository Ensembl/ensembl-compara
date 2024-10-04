=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor

=head1 DESCRIPTION

Adaptor for a GeneTree object (individual nodes will be internally retrieved
with the GeneTreeNodeAdaptor).

=cut

package Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::GeneTree;
use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');

#
# FETCH methods
###########################

=head2 fetch_all

  Arg [-TREE_TYPE] (opt)
             : string: the type of trees that have to be fetched
               Currently one of 'clusterset', 'supertree', 'tree'
  Arg [-MEMBER_TYPE] (opt)
             : string: the type of the members that are part of the tree
               Currently 'protein' or 'ncrna'
  Arg [-METHOD_LINK_SPECIES_SET] (opt)
             : MethodLinkSpeciesSet or int: either the object or its dbID
               NB: It currently gives the same partition of the data as member_type
  Arg [-CLUSTERSET_ID] (opt)
             : string: the name of the clusterset (use "default" to get the default
               trees). Currently, there is a clusterset for the default trees, one for
               each phylogenetic model used in the protein tree pipeline
  Example    : $all_trees = $genetree_adaptor->fetch_all();
  Description: Fetches from the database all the gene trees
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTree
  Exceptions : none
  Caller     : general

=cut

sub fetch_all {
    my ($self, @args) = @_;
    my ($clusterset_id, $mlss, $tree_type, $member_type)
        = rearrange([qw(CLUSTERSET_ID METHOD_LINK_SPECIES_SET TREE_TYPE MEMBER_TYPE)], @args);
    my @constraint = ();

    if (defined $tree_type) {
        push @constraint, '(gtr.tree_type = ?)';
        $self->bind_param_generic_fetch($tree_type, SQL_VARCHAR);
    }

    if (defined $member_type) {
        push @constraint, '(gtr.member_type = ?)';
        $self->bind_param_generic_fetch($member_type, SQL_VARCHAR);
    }

    if (defined $mlss) {
        assert_ref_or_dbID($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss');
        my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
        push @constraint, '(gtr.method_link_species_set_id = ?)';
        $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    }

    if (defined $clusterset_id) {
        push @constraint, '(gtr.clusterset_id = ?)';
        $self->bind_param_generic_fetch($clusterset_id, SQL_VARCHAR);
    }

    return $self->generic_fetch(join(' AND ', @constraint));
}


=head2 fetch_by_stable_id

  Arg[1]     : string $tree_stable_id
  Example    : $tree = $genetree_adaptor->fetch_by_stable_id("ENSGT00590000083078");
  Description: Fetches from the database the gene tree for that stable ID
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : returns undef if $stable_id is not found.
  Caller     : general

=cut

sub fetch_by_stable_id {
    my ($self, $stable_id) = @_;

    $self->bind_param_generic_fetch($stable_id, SQL_VARCHAR);
    return $self->generic_fetch_one('gtr.stable_id = ?');
}


=head2 fetch_by_root_id

  Arg[1]     : int $tree_root_id
  Example    : $tree = $genetree_adaptor->fetch_by_root_id(3);
  Description: Fetches from the database the gene tree for that root ID
               This is equivalent to fetch_by_dbID
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : returns undef if $root_id is not found.
  Caller     : general

=cut

sub fetch_by_root_id {
    my ($self, $root_id) = @_;

    $self->bind_param_generic_fetch($root_id, SQL_INTEGER);
    return $self->generic_fetch_one('gtr.root_id = ?');
}


=head2 fetch_by_dbID

  Arg[1]     : int $tree_root_id
  Example    : $tree = $genetree_adaptor->fetch_by_dbID(3);
  Description: Fetches from the database the gene tree for that root ID
               This is equivalent to fetch_by_root_id
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : returns undef if $root_id is not found.
  Caller     : general

=cut

sub fetch_by_dbID {
    my ($self, $root_id) = @_;

    $self->bind_param_generic_fetch($root_id, SQL_INTEGER);
    return $self->generic_fetch_one('gtr.root_id = ?');
}


=head2 fetch_by_node_id

  Arg[1]     : int $tree_node_id
  Example    : $tree = $genetree_adaptor->fetch_by_node_id(3);
  Description: Fetches from the database the gene tree that contains
               this node
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : returns undef if $node_id is not found.
  Caller     : general

=cut

sub fetch_by_node_id {
    my ($self, $node_id) = @_;

    $self->bind_param_generic_fetch($node_id, SQL_INTEGER);
    my $join = [[['gene_tree_node', 'gtn'], 'gtn.root_id = gtr.root_id']];
    return $self->generic_fetch_one('gtn.node_id = ?', $join);
}


=head2 fetch_all_by_Member

  Arg[1]     : GeneMember, SeqMember or seq_member_id
  Arg [-METHOD_LINK_SPECIES_SET] (opt)
             : MethodLinkSpeciesSet or int: either the object or its dbID
  Arg [-CLUSTERSET_ID] (opt)
             : string: the name of the clusterset (default is "default")
  Example    : $all_trees = $genetree_adaptor->fetch_all_by_Member($member);
  Description: Fetches from the database all the gene trees that contains this member
               If the member is a non-canonical SeqMember, returns an empty list
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTree
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Member {
    my ($self, $member, @args) = @_;
    my ($clusterset_id, $mlss) = rearrange([qw(CLUSTERSET_ID METHOD_LINK_SPECIES_SET)], @args);

    assert_ref_or_dbID($member, 'Bio::EnsEMBL::Compara::Member', 'member');

    my $join = [[['gene_tree_node', 'gtn'], 'gtn.root_id = gtr.root_id']];
    my $constraint = '(gtn.seq_member_id = ?)';
    
    my $seq_member_id = (ref($member) ? ($member->isa('Bio::EnsEMBL::Compara::GeneMember') ? $member->canonical_member_id : $member->dbID) : $member);
    $self->bind_param_generic_fetch($seq_member_id, SQL_INTEGER);
    
    if (defined $mlss) {
        assert_ref_or_dbID($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss');
        my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
        $constraint .= ' AND (gtr.method_link_species_set_id = ?)';
        $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    }
    if (defined $clusterset_id) {
        $constraint .= ' AND (gtr.clusterset_id = ?)';
        $self->bind_param_generic_fetch($clusterset_id, SQL_VARCHAR);
    }

    return $self->generic_fetch($constraint, $join);
}


=head2 fetch_default_for_Member

  Arg[1]     : GeneMember, SeqMember or seq_member_id
  Arg[2]     : (optional) clusterset_id (example values: "default", "murinae")
  Example    : $trees = $genetree_adaptor->fetch_default_for_Member($member);
  Description: Fetches from the database the default gene tree that contains this member
               If the member is a non-canonical SeqMember, returns undef
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : none
  Caller     : general

=cut

sub fetch_default_for_Member {
    my ($self, $member, $clusterset_id) = @_;

    my $all_trees = $self->fetch_all_by_Member($member, -CLUSTERSET_ID => $clusterset_id);
    return $all_trees->[0] if scalar(@$all_trees) == 1;
    my @sorted_trees = sort {$a->root_id <=> $b->root_id} grep {!$_->ref_root_id} @$all_trees;
    return $sorted_trees[0];
}


=head2 fetch_by_Gene

  Arg[1]     : Bio::EnsEMBL::Gene $gene
  Example    : $tree = $genetree_adaptor->fetch_by_Gene($gene);
  Description: Fetches from the database the default gene tree that contains this gene
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : none
  Caller     : general

=cut

sub fetch_by_Gene {
    my ($self, $gene) = @_;

    assert_ref($gene, 'Bio::EnsEMBL::Gene', 'gene');
    my $gene_member = $self->db->get_GeneMemberAdaptor->fetch_by_Gene($gene);
    return $gene_member ? $self->fetch_default_for_Member($gene_member) : undef;
}


=head2 fetch_parent_tree

  Arg[1]     : GeneTree $tree or its root_id
  Example    : $parent = $genetree_adaptor->fetch_parent_tree($tree);
  Description: Fetches from the database the parent (tree) of the argument tree
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions : returns undef if called on a 'clusterset' tree
  Caller     : general

=cut

sub fetch_parent_tree {
    my ($self, $tree) = @_;

    assert_ref_or_dbID($tree, 'Bio::EnsEMBL::Compara::GeneTree', 'tree');
    my $tree_id = (ref($tree) ? $tree->root_id : $tree);

    my $join = [[['gene_tree_node', 'gtn1'], 'gtn1.root_id = gtr.root_id'], [['gene_tree_node', 'gtn2'], 'gtn1.node_id = gtn2.parent_id']];
    my $constraint = "(gtn2.root_id = gtn2.node_id) AND (gtn2.root_id = ?)";
    
    $self->bind_param_generic_fetch($tree_id, SQL_INTEGER);
    return $self->generic_fetch_one($constraint, $join);
}


=head2 fetch_subtrees

  Arg[1]     : GeneTree $tree or its root_id
  Example    : $subtrees = $genetree_adaptor->fetch_subtrees($tree);
  Description: Fetches from the database the trees that are children of the argument tree
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTree
  Exceptions : the array is empty if called on a 'tree' tree
  Caller     : general

=cut

sub fetch_subtrees {
    my ($self, $tree) = @_;

    assert_ref_or_dbID($tree, 'Bio::EnsEMBL::Compara::GeneTree', 'tree');
    my $tree_id = (ref($tree) ? $tree->root_id : $tree);

    my $join = [[['gene_tree_node', 'gtn2'], 'gtn2.node_id = gtr.root_id', {'gtn2.parent_id' => '_parent_id'}], [['gene_tree_node', 'gtn1'], 'gtn1.node_id = gtn2.parent_id']];
    my $constraint = "(gtn1.root_id = ?) AND (gtn2.root_id != gtn1.root_id)";

    $self->bind_param_generic_fetch($tree_id, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join);
}


=head2 fetch_all_linked_trees

  Arg[1]     : GeneTree $tree or its root_id
  Example    : $othertrees = $genetree_adaptor->fetch_all_linked_trees($tree);
  Description: Fetches from the database all trees that are associated to the argument tree.
                The other trees generally contain the same members, but are either build
                with a different phylogenetic model, or have a different multiple alignment.
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTree
  Caller     : general

=cut

sub fetch_all_linked_trees {
    my ($self, $tree) = @_;

    # Currently, all linked trees are accessible in 1 hop
    if ($tree->ref_root_id) {
        # Trees that share the same reference
        $self->bind_param_generic_fetch($tree->ref_root_id, SQL_INTEGER);
        $self->bind_param_generic_fetch($tree->root_id, SQL_INTEGER);
        $self->bind_param_generic_fetch($tree->ref_root_id, SQL_INTEGER);
        return $self->generic_fetch('(ref_root_id = ? AND root_id != ?) OR (root_id = ?)');
    } else {
        # The given tree is the reference
        $self->bind_param_generic_fetch($tree->root_id, SQL_INTEGER);
        return $self->generic_fetch('ref_root_id = ?');
    }
}

=head2 fetch_all_removed_seq_member_ids_by_root_id

  Arg[1]     : int: root_id: ID of the root node of the tree
  Example    : $all_removed_members = $genetree_adaptor->fetch_all_Removed_Members_by_root_id($root_id);
  Description: Gets all the removed members of the given tree.
  Returntype : arrayref of seq_member_ids
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_removed_seq_member_ids_by_root_id {
    my ( $self, $root_id ) = @_;

    return $self->dbc->db_handle->selectcol_arrayref( 'SELECT seq_member_id FROM gene_tree_backup WHERE is_removed = 1 AND root_id = ? ;', undef, $root_id );
}

# Fetch consensus-tree LCA nodes for the given member in the form of
# a mapping of target seq_member_id to clusterset-ancestor pairs.
sub _fetch_all_ref_lca_node_ids_by_Member {
    my ($self, $member) = @_;

    assert_ref_or_dbID($member, 'Bio::EnsEMBL::Compara::Member', 'member');
    my $seq_member_id;
    if (ref($member)) {

        if ($member->isa('Bio::EnsEMBL::Compara::GeneMember')) {
            $seq_member_id = $member->canonical_member_id;
        } else {  # $member->isa('Bio::EnsEMBL::Compara::SeqMember')
            $seq_member_id = $member->dbID;
        }

    } else {
        $seq_member_id = $member
    }

    my $dbh = $self->dbc->db_handle;

    # With this query of trees containing the relevant member, ordering by root_id allows us to
    # fetch trees in order of clusterset precedence (e.g. 'default', 'protostomes', 'insects').
    my $tree_query = q/
        SELECT
            node_id,
            root_id,
            clusterset_id
        FROM
            gene_tree_node
        JOIN
            gene_tree_root gtr
        USING
            (root_id)
        WHERE
            seq_member_id = ?
        AND
            ref_root_id IS NULL
    /;

    my $tree_query_results = $dbh->selectall_hashref($tree_query, 'root_id', undef, $seq_member_id);

    my @tree_root_ids;
    my %root_to_clusterset_id;
    my %root_to_query_node_id;
    while (my ($root_id, $row) = each %$tree_query_results) {
        $root_to_clusterset_id{$root_id} = $row->{'clusterset_id'};
        $root_to_query_node_id{$root_id} = $row->{'node_id'};
        push(@tree_root_ids, $root_id);
    }
    @tree_root_ids = sort { $a <=> $b } @tree_root_ids;

    my @root_id_placeholders = ('?') x @tree_root_ids;
    my $root_id_placeholder_str = '(' . join(',', @root_id_placeholders) . ')';

    my $node_query = qq/
        SELECT
            node_id,
            root_id,
            left_index,
            right_index,
            seq_member_id
        FROM
            gene_tree_node
        WHERE
            root_id IN $root_id_placeholder_str;
    /;

    my $results_by_node = $dbh->selectall_hashref($node_query, 'node_id', undef, @tree_root_ids);

    my %results_by_tree;
    while (my ($node_id, $row) = each %$results_by_node) {
        $results_by_tree{$row->{'root_id'}}{$node_id} = $row;
    }

    my %ref_lca_node_map;
    foreach my $root_id (@tree_root_ids) {
        my $clusterset_id = $root_to_clusterset_id{$root_id};
        my $tree_results = $results_by_tree{$root_id};

        my @tree_idxs;
        my %node_to_idxs;
        my $query_left_idx;
        my $query_right_idx;
        my %node_to_seq_member_id;

        # To find LCA nodes using tree indices, we create an array
        # of the tree indices in which the values are node IDs ...
        while (my ($node_id, $row) = each %$tree_results) {
            my $left_idx = $row->{'left_index'};
            my $right_idx = $row->{'right_index'};

            $tree_idxs[$left_idx] = $node_id;
            $tree_idxs[$right_idx] = $node_id;

            $node_to_idxs{$node_id} = {
                'left_index' => $left_idx,
                'right_index' => $right_idx,
            };

            if (defined $row->{'seq_member_id'}) {
                $node_to_seq_member_id{$node_id} = $row->{'seq_member_id'};
                if ($node_id == $root_to_query_node_id{$root_id}) {
                    $query_left_idx = $left_idx;
                    $query_right_idx = $right_idx;
                }
            }
        }

        # ... then we check the tree-index array to the left of the query ...
        my @left_node_stack;
        for (my $i = $query_left_idx - 1 ; $i > 0; $i--) {
            my $node_id = $tree_idxs[$i];
            if (exists $node_to_seq_member_id{$node_id}) {
                next if @left_node_stack && $left_node_stack[-1] == $node_id;
                push(@left_node_stack, $node_id);
            } elsif ($node_to_idxs{$node_id}{'right_index'} > $query_right_idx) {
                while (@left_node_stack) {
                    my $target_node_id = pop(@left_node_stack);
                    my $target_member_id = $node_to_seq_member_id{$target_node_id};
                    push(@{$ref_lca_node_map{$target_member_id}}, [$clusterset_id, $node_id]);
                }
            }
        }

        # ... and finally we check the tree-index array to the right of the query.
        my @right_node_stack;
        for (my $j = $query_right_idx + 1 ; $j < scalar(@tree_idxs); $j++) {
            my $node_id = $tree_idxs[$j];
            if (exists $node_to_seq_member_id{$node_id}) {
                next if @right_node_stack && $right_node_stack[-1] == $node_id;
                push(@right_node_stack, $node_id);
            } elsif ($node_to_idxs{$node_id}{'left_index'} < $query_left_idx) {
                while (@right_node_stack) {
                    my $target_node_id = pop(@right_node_stack);
                    my $target_member_id = $node_to_seq_member_id{$target_node_id};
                    push(@{$ref_lca_node_map{$target_member_id}}, [$clusterset_id, $node_id]);
                }
            }
        }

        # After checking the tree-index array, we should have
        # found the LCA node of the query and each target.
        my $num_targets_without_lca = scalar(@left_node_stack) + scalar(@right_node_stack);
        if ($num_targets_without_lca > 0) {
            throw("LCA node not found for $num_targets_without_lca target members in indexed tree with ID $root_id");
        }
    }

    return \%ref_lca_node_map
}


#
# STORE/DELETE methods
###########################

sub store {
    my ($self, $tree) = @_;

    # Firstly, store the nodes
    my $has_root_id = (exists $tree->{'_root_id'} ? 1 : 0);
    my $root_id = $self->db->get_GeneTreeNodeAdaptor->store_nodes_rec($tree->root);
    $tree->{'_root_id'} = $root_id;

    # Secondly, the tree itself
    my $sth;
    # Make sure that the variables are in the same order
    if ($has_root_id) {
        $sth = $self->prepare('UPDATE gene_tree_root SET tree_type=?, member_type=?, clusterset_id=?, gene_align_id=?, method_link_species_set_id=?, species_tree_root_id=?, stable_id=?, version=?, ref_root_id=? WHERE root_id=?'),
    } else {
        $sth = $self->prepare('INSERT INTO gene_tree_root (tree_type, member_type, clusterset_id, gene_align_id, method_link_species_set_id, species_tree_root_id, stable_id, version, ref_root_id, root_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    }
    $sth->execute($tree->tree_type, $tree->member_type, $tree->clusterset_id, $tree->gene_align_id, $tree->method_link_species_set_id, $tree->species_tree_root_id, $tree->stable_id, $tree->version, $tree->ref_root_id, $root_id);

    $tree->adaptor($self);

    return $root_id;
}

sub delete_tree {
    my ($self, $tree) = @_;

    assert_ref($tree, 'Bio::EnsEMBL::Compara::GeneTree', 'tree');

    # Make sure the tags are loaded (so that we can access the tags that
    # link to alternative alignments)
    $tree->_load_tags;

    my $root_id = $tree->root->node_id;
    my $clusterset_id = $tree->clusterset_id;
    # Query to reset gene_member_hom_stats
    my $gene_member_hom_stats_sql = qq/
        UPDATE gene_member_hom_stats
        SET
            gene_trees = 0,
            orthologues = 0,
            paralogues = 0,
            homoeologues = 0
        WHERE
            gene_member_id = ?
                AND collection = "$clusterset_id"
    /;
    for my $leaf (@{$tree->get_all_leaves}) {
        if ($leaf->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
            $self->dbc->do($gene_member_hom_stats_sql, undef, $leaf->gene_member_id);
        }
    }

    # Delete any associated CAFE data
    my $cafe_adaptor = $self->db->get_CAFEGeneFamilyAdaptor;
    my $cafe_gene_family = $cafe_adaptor->fetch_by_GeneTree($tree);
    $cafe_adaptor->delete($cafe_gene_family) if ( $cafe_gene_family );

    # Remove all the nodes but the root
    my $gene_tree_node_Adaptor = $self->db->get_GeneTreeNodeAdaptor;
    for my $node (@{$tree->get_all_nodes}) {
        next if ($node->node_id() == $root_id);
        $gene_tree_node_Adaptor->delete_node($node);
    }

    # List of all the gene_align_ids that need deleting
    my %gene_align_ids;
    $gene_align_ids{$tree->gene_align_id} = 1 if $tree->gene_align_id;

    # Only for "default" trees
    unless ($tree->ref_root_id) {

        # Linked trees must be removed as well as they refer to the default tree
        foreach my $other_tree (@{$self->fetch_all_linked_trees($tree)}) {
            $gene_align_ids{$other_tree->gene_align_id} = 1 if $other_tree->gene_align_id;
            $other_tree->preload();
            $self->delete_tree($other_tree);
            $other_tree->release_tree();
        }
    }

    if (my $gene_count = $tree->get_value_for_tag('gene_count')) {
        my $current_tree = $tree;
        while (my $parent_tree = $self->fetch_parent_tree($current_tree)) {
            if (my $parent_gene_count = $parent_tree->get_value_for_tag('gene_count')) {
                $parent_tree->store_tag('gene_count', $parent_gene_count-$gene_count);
                $current_tree = $parent_tree;
            } else {
                last;
            }
        }
    }

    # Is this a subtree of a supertree? If so, clean up the supertree too
    if ( defined $tree->root->parent->tree and $tree->root->parent->tree->tree_type eq 'supertree' ) {
        $self->_clean_supertree($tree->root);
    }

    # Finally remove the root node
    $gene_tree_node_Adaptor->delete_node($tree->root) if $tree->root;

    # Only for "default" trees
    unless ($tree->ref_root_id) {
        # Register more alignments
        foreach my $gene_align_id_tag (qw(mcoffee_scores_gene_align_id filtered_gene_align_id)) {
            if (my $gene_align_id = $tree->get_value_for_tag($gene_align_id_tag)) {
                $gene_align_ids{$gene_align_id} = 1;
            }
        }
        # Delete all the alignments (no foreign key problems since all the
        # trees have been removed by now)
        foreach my $gene_align_id (keys %gene_align_ids) {
            $self->db->get_GeneAlignAdaptor->delete($gene_align_id);
        }

        # The HMM profile
        $self->dbc->do('DELETE FROM hmm_profile WHERE model_id = ?', undef, $root_id);
    }

}

sub _clean_supertree {
    my ($self, $subtree_root) = @_;

    my $gtn_adaptor = $self->db->get_GeneTreeNodeAdaptor;

    my $supertree_leaf = $subtree_root->parent;
    my $supertree_root = $supertree_leaf->root;
    my $supertree_gene_align_id = $supertree_root->tree->gene_align_id;

    my @supertree_leaves = @{$supertree_root->tree->get_all_leaves};
    my @supertree_leaf_ids = map {$_->node_id} @supertree_leaves;
    if ( scalar(@supertree_leaves) < 3 ) {
        # removing a node from this supertree results in a single-leaf tree
        # delete the whole supertree, leaving the other subtree intact
        foreach my $supertree_leaf ( @supertree_leaves ) {
            # link the subtree to the supertree's parent
            # this is usually a clusterset, but may be another supertree
            # (there is no easy way to do this using API calls in place of raw SQL)
            my $unlink_subtree_sql = "UPDATE gene_tree_node SET parent_id = ? WHERE parent_id = ?";
            my $sth = $self->prepare($unlink_subtree_sql);
            $sth->execute($supertree_root->parent->node_id, $supertree_leaf->node_id);
        }

        $self->delete_tree($supertree_root->tree);
    } else {
        # remove the deleted subtree's parent node and minimize the supertree
        # (i.e. clean up single-child nodes)
        $gtn_adaptor->delete_node($supertree_leaf);
        my $pruned_supertree = $supertree_root->tree;
        my @orig_child_nodes = map {$_->node_id} @{$pruned_supertree->root->get_all_nodes()};

        # clean the tree, update the indexes, update the tree in the db
        my $minimized_tree = $pruned_supertree->root->minimize_tree;
        # sometimes minimize_tree removes the old root - replace the original root_id
        $minimized_tree->root->node_id($supertree_root->node_id);
        # delete any nodes that have been removed in the minimization process from db
        my %minimized_child_nodes = map {$_->node_id => 1} @{$minimized_tree->get_all_nodes()};
        foreach my $orig_child_id ( @orig_child_nodes ) {
            next if $minimized_child_nodes{$orig_child_id};
            $gtn_adaptor->delete_node($gtn_adaptor->fetch_by_dbID($orig_child_id));
        }
        $minimized_tree->root->build_leftright_indexing();
        $gtn_adaptor->update_subtree($minimized_tree);
        $supertree_root = $minimized_tree->root;

        # now remove subtree's members from the supertree alignment
        my $subtree_members = $subtree_root->tree->get_all_Members;
        $self->db->get_GeneAlignAdaptor->delete_members($supertree_gene_align_id, $subtree_root->tree->get_all_Members);

        # memory management
        $pruned_supertree->release_tree;
        $minimized_tree->release_tree;
    }
}

sub change_clusterset {
    my ($self, $tree, $target_clusterset) = @_;

    my $sth;
    $sth = $self->prepare('SELECT root_id FROM gene_tree_root WHERE tree_type = "clusterset" AND clusterset_id = ? ;'),
    $sth->execute($target_clusterset);
    my $target_clusterset_root_id = $sth->fetchrow();
    $sth->finish();

    my $cluster_set_leave = $tree->root->parent;

    $sth = $self->prepare('UPDATE gene_tree_node SET parent_id=?, root_id=? WHERE node_id=? and seq_member_id IS NULL'),
    $sth->execute($target_clusterset_root_id, $target_clusterset_root_id , $cluster_set_leave->node_id);
    $sth->finish();

    $sth = $self->prepare('UPDATE gene_tree_root SET clusterset_id=? WHERE root_id=?'),
    $sth->execute($target_clusterset, $tree->root->node_id);
    $sth->finish();
}

#
# Virtual methods from TagAdaptor
###################################

sub _tag_capabilities {
    return ('gene_tree_root_tag', 'gene_tree_root_attr', 'root_id', 'root_id', 'tag', 'value');
}


#
# Virtual methods from BaseAdaptor
####################################

sub _tables {

    return (['gene_tree_root', 'gtr'], ['gene_align', 'ga'])
}

sub _left_join {
    return (
        ['gene_align', 'gtr.gene_align_id = ga.gene_align_id'],
    );
}


sub _columns {

    return qw (
        gtr.root_id
        gtr.tree_type
        gtr.member_type
        gtr.clusterset_id
        gtr.gene_align_id
        gtr.method_link_species_set_id
        gtr.species_tree_root_id
        gtr.stable_id
        gtr.version
        gtr.ref_root_id
        ga.seq_type
        ga.aln_length
        ga.aln_method
    );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::GeneTree', [
            '_root_id',
            '_tree_type',
            '_member_type',
            '_clusterset_id',
            '_gene_align_id',
            '_method_link_species_set_id',
            '_species_tree_root_id',
            '_stable_id',
            '_version',
            '_ref_root_id',
            '_seq_type',
            '_aln_length',
            '_aln_method',
        ] );
}


1;
