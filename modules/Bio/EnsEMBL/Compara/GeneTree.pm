=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::GeneTree

=head1 DESCRIPTION

Class to represent a gene tree object. Contains a link to
the root of the tree, as long as general tree properties.
It implements the AlignedMemberSet interface (via the leaves).

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTree
  +- Bio::EnsEMBL::Compara::AlignedMemberSet
  `- Bio::EnsEMBL::Compara::Taggable

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::GeneTree;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;

use strict;
no strict 'refs';

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet', 'Bio::EnsEMBL::Compara::Taggable');


##############################
# Constructors / Destructors #
##############################

=head2 new

  Arg [1]    :
  Example    :
  Description:
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Exceptions :
  Caller     :

=cut

sub new {
    my($class,@args) = @_;

    my $self = $class->SUPER::new(@args);

    if (scalar @args) {
        my ($root_id, $member_type, $tree_type, $clusterset_id) = rearrange([qw(ROOT_ID MEMBER_TYPE TREE_TYPE CLUSTERSET_ID)], @args);

        $self->{'_root_id'} = $root_id if defined $root_id;
        $member_type && $self->member_type($member_type);
        $tree_type && $self->tree_type($tree_type);
        $clusterset_id && $self->clusterset_id($clusterset_id);
    }

    return $self;
}


=head2 deep_copy

  Description: Returns a copy of $self (as an AlignedMemberSet). All the
               members are themselves copied, but the tree topology is lost.
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Caller     : General

=cut

sub deep_copy {
    my $self = shift;
    my $copy = $self->SUPER::deep_copy();
    foreach my $attr (qw(tree_type member_type clusterset_id)) {
        $copy->$attr($self->$attr);
    }
    return $copy;
}


=head2 DESTROY

  Description : Deletes the reference to the root node and breaks
                the circular reference.
  Returntype  : None
  Caller      : System

=cut

sub DESTROY {
    my $self = shift;
    delete $self->{'_root'};
}


#####################
# Object attributes #
#####################

=head2 tree_type

  Description : Getter/Setter for the tree_type field. This field can
                currently be 'tree', 'supertree' or 'clusterset'
  Returntype  : String
  Example     : my $type = $tree->tree_type();
  Caller      : General

=cut

sub tree_type {
    my $self = shift;
    $self->{'_tree_type'} = shift if(@_);
    return $self->{'_tree_type'};
}


=head2 member_type

  Description : Getter/Setter for the member_type field. This field can
                currently be 'ncrna' or 'protein'
  Returntype  : String
  Example     : my $type = $tree->member_type();
  Caller      : General

=cut

sub member_type {
    my $self = shift;
    $self->{'_member_type'} = shift if(@_);
    return $self->{'_member_type'};
}


=head2 clusterset_id

  Description : Getter/Setter for the clusterset_id field. This field can
                be any string. Each dataset should contain a set of trees
                with the "default" clusterset_id. Other clusterset_id are
                used to store linked / additionnal data.
  Returntype  : String
  Example     : my $clusterset_id = $tree->clusterset_id();
  Caller      : General

=cut

sub clusterset_id {
    my $self = shift;
    $self->{'_clusterset_id'} = shift if(@_);
    return $self->{'_clusterset_id'};
}


=head2 root_id

  Description : Getter for the root_id of the root node of the tree.
  Returntype  : Integer
  Example     : my $root_node_id = $tree->root_id();
  Caller      : General

=cut

sub root_id {
    my $self = shift;
    return $self->{'_root_id'};
}


################
# Tree loading #
################

=head2 root

  Description : Getter for the root node of the tree. This returns an
                object fetch from the database if root_id is defined.
                Otherwise, it will create a new GeneTreeNode object.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode
  Example     : my $root_node = $tree->root();
  Caller      : General

=cut

sub root {
    my $self = shift;

    if (not defined $self->{'_root'}) {
        if (defined $self->{'_root_id'} and defined $self->adaptor) {
            # Loads all the nodes in one go
            my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
            $gtn_adaptor->{'_ref_tree'} = $self;
            $self->{'_root'} = $gtn_adaptor->fetch_node_by_node_id($self->{'_root_id'});
            delete $gtn_adaptor->{'_ref_tree'};

        } else {
            # Creates a new GeneTreeNode object
            $self->{'_root'} = new Bio::EnsEMBL::Compara::GeneTreeNode;
            $self->{'_root'}->tree($self);
        }
    }
    return $self->{'_root'};
}


=head2 preload

  Description : Method to load all the tree data in one go. This currently
                includes if not loaded yet, and all the gene Members
                associated with the leaves.
                In the future, it will include all the tags
  Returntype  : node
  Example     : $tree->preload();
  Caller      : General

=cut

sub preload {
    my $self = shift;
    return unless defined $self->adaptor;

    if (not defined $self->{'_root'} and defined $self->{'_root_id'}) {
        my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
        $gtn_adaptor->{'_ref_tree'} = $self;
        $self->{'_root'} = $gtn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
        delete $gtn_adaptor->{'_ref_tree'};
    }

    # Loads all the gene members in one go
    my %leaves;
    foreach my $pm (@{$self->root->get_all_leaves}) {
        $leaves{$pm->gene_member_id} = $pm if UNIVERSAL::isa($pm, 'Bio::EnsEMBL::Compara::GeneTreeMember');
    }
    my @m_ids = keys(%leaves);
    my $all_gm = $self->adaptor->db->get_MemberAdaptor->fetch_all_by_dbID_list(\@m_ids);
    foreach my $gm (@$all_gm) {
        $leaves{$gm->dbID}->gene_member($gm);
    }
}


=head2 attach_alignment

  Arg [1]     : String: clusterset_id
  Description : Method to fetch the alternative tree with the given
                clusterset_id and attach its multiple alignment to
                the current tree. The alternative tree is returned.
  Returntype  : GeneTree
  Example     : $supertree->attach_alignment('super-align');
  Caller      : General

=cut

sub attach_alignment {
    my $self = shift;
    my $other_clusterset_id = shift;
    return unless defined $self->adaptor;

    # Gets the other tree
    my $others = $self->adaptor->fetch_all_linked_trees($self);
    my @good_others = grep {$_->clusterset_id eq $other_clusterset_id} @$others;
    die "'$other_clusterset_id' tree not found\n" unless scalar(@good_others);

    # Gets the alignment
    my %cigars;
    my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
    foreach my $leaf (@{$gtn_adaptor->fetch_all_AlignedMember_by_root_id($good_others[0]->root_id)}) {
        $cigars{$leaf->member_id} = $leaf->cigar_line;
    }

    # Assigns it
    foreach my $leaf (@{$self->root->get_all_leaves}) {
        $leaf->cigar_line($cigars{$leaf->member_id});
    }

    return $good_others[0];
}


=head2 expand_subtrees

  Description : Method to fetch the subtrees of the current tree
                and attach them to the tips of the current tree
  Returntype  : none
  Example     : $supertree->expand_subtrees();
  Caller      : General

=cut

sub expand_subtrees {
    my $self = shift;
    return unless defined $self->adaptor;

    # Gets the subtrees
    my %subtrees;
    foreach my $subtree (@{$self->adaptor->fetch_subtrees($self)}) {
        $subtree->preload;
        $subtrees{$subtree->root->_parent_id} = $subtree->root;
    }

    # Attaches them
    $self->preload;
    foreach my $leaf (@{$self->root->get_all_leaves}) {
        next unless exists $subtrees{$leaf->node_id};
        $leaf->parent->add_child($subtrees{$leaf->node_id});
        $leaf->disavow_parent;
    }
}


##############################
# AlignedMemberSet interface #
##############################

=head2 member_class

  Description: Returns the type of member used in the set
  Returntype : String: Bio::EnsEMBL::Compara::GeneTreeMember
  Caller     : Bio::EnsEMBL::Compara::MemberSet

=cut

sub member_class {
    return 'Bio::EnsEMBL::Compara::GeneTreeMember';
}


=head2 get_all_Members

  Example    :
  Description: Returns the list of all the GeneTreeMember of the tree
  Returntype : array reference of Bio::EnsEMBL::Compara::GeneTreeMember
  Caller     : General

=cut

sub get_all_Members {
    my ($self) = @_;

    unless (defined $self->{'_member_array'}) {

        $self->{'_member_array'} = [];
        $self->{'_members_by_source'} = {};
        $self->{'_members_by_source_taxon'} = {};
        $self->{'_members_by_source_genome_db'} = {};
        $self->{'_members_by_genome_db'} = {};
        foreach my $leaf (@{$self->root->get_all_leaves}) {
            $self->SUPER::add_Member($leaf) if UNIVERSAL::isa($leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember');
        }
    }
    return $self->{'_member_array'};
}


=head2 add_Member

  Arg [1]    : GeneTreeMember
  Example    :
  Description: Add a new GeneTreeMember to this set and to the tree as
               a child of the root node
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : General

=cut

sub add_Member {
    my ($self, $member) = @_;
    assert_ref($member, 'Bio::EnsEMBL::Compara::GeneTreeMember');
    $self->root->add_child($member);
    $member->tree($self);
    $self->SUPER::add_Member($member);
}


########
# Misc #
########

# Dynamic definition of functions to allow NestedSet methods work with GeneTrees
foreach my $func_name (qw(get_all_nodes get_all_leaves get_all_sorted_leaves
                          find_leaf_by_node_id find_leaf_by_name find_node_by_node_id
                          find_node_by_name remove_nodes build_leftright_indexing flatten_tree
                          newick_format nhx_format string_tree print_tree
                          release_tree
                        )) {
    my $full_name = "Bio::EnsEMBL::Compara::GeneTree::$func_name";
    *$full_name = sub {
        my $self = shift;
        my $ret = $self->root->$func_name(@_);
        return $ret;
    };
#    print STDERR "REDEFINE $func_name\n";
}


1;

