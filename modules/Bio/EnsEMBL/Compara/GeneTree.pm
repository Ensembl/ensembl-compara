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


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::GeneTree

=head1 DESCRIPTION

Class to represent a gene tree object.
It implements the AlignedMemberSet interface (via the leaves).

A GeneTree object is merely a wrapper aroung the root node (GeneTreeNode), with a few additional general tree properties.

A gene tree is defined on a set of genes (members) of the same type ('protein' or 'ncrna').
It is reconciled with a species tree that guides their structure (speciations, duplications, gene losses)

The final / default gene trees are a mixture of various methods / phylogenetic models. Each set of tree is part of a "clusterset", the default being "default".
The tree are themselves organized as a giant tree structure of types 'supertree' and 'clusterset'.
Super-trees link trees of the same gene family that were too large to build a tree on in a single pass (e.g. the U6 snRNA, the HOX family)
This results in the following hierarchy of GeneTree tree_type/member_type:

 clusterset/protein
 +- supertree/protein
 |  +- tree/protein
 |  `- tree/protein
 +- supertree/protein
 |  ...
 +- tree/protein
 +- tree/protein
 |  ...
 `- tree/protein

 clusterset/ncrna
 +- supertree/ncrna
 |  +- tree/ncrna
 |  `- tree/ncrna
 +- supertree/ncrna
 |  ...
 +- tree/ncrna
 +- tree/ncrna
 |  ...
 `- tree/ncrna

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTree
  +- Bio::EnsEMBL::Compara::AlignedMemberSet
  `- Bio::EnsEMBL::Compara::Taggable

=head1 SYNOPSIS

The additionnal getter / setters are:
 - root()
 - member_type()
 - tree_type()
 - clusterset_id()
 - species_tree()
 - alignment()

As dbID() can be misleading for composite objects, please refer to:
 - root_id() (for the tree itself)
 - gene_align_id() (for the underlying sequence alignment)
 - ref_root_id() (root_id of the default tree, when this one is not in the default clusterset)

A few methods affect the structure of the nodes:
 - preload()
 - expand_subtrees()

And finally, GeneTree aliases a few GeneTreeNode methods that actually apply on the root node:
 - get_all_nodes()
 - get_all_leaves()
 - get_all_sorted_leaves()
 - get_leaf_by_Member()
 - find_leaf_by_node_id()
 - find_leaf_by_name()
 - find_node_by_node_id()
 - find_node_by_name()
 - newick_format()
 - nhx_format()
 - print_tree()

WARNING - Memory leak
Our current object model uses a cyclic graph of Perl references.
As a consequence, the usual garbage-collector is not able to release the
memory used by a gene tree when you lose its reference (unlike most of the
Ensembl objects). This means that you will have to call release_tree() on
each tree after using it.


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::GeneTree;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;

use strict;
use warnings;

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
        my ($root_id, $member_type, $tree_type, $clusterset_id, $ref_root_id, $gene_align_id) =
            rearrange([qw(ROOT_ID MEMBER_TYPE TREE_TYPE CLUSTERSET_ID REF_ROOT_ID GENE_ALIGN_ID)], @args);

        $self->{'_root_id'} = $root_id if defined $root_id;
        $member_type && $self->member_type($member_type);
        $tree_type && $self->tree_type($tree_type);
        $clusterset_id && $self->clusterset_id($clusterset_id);
        $ref_root_id && $self->ref_root_id($ref_root_id);
        $gene_align_id && $self->gene_align_id($gene_align_id);
    }

    return $self;
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


=head2 ref_root_id

  Description : Getter/Setter for the ref_root_id field. This field must
                link to a valid root_id. It refers to the main tree (the
                tree in the "default" clusterset).
  Returntype  : Integer
  Example     : my $ref_root_id = $tree->ref_root_id();
  Caller      : General

=cut

sub ref_root_id {
    my $self = shift;
    $self->{'_ref_root_id'} = shift if(@_);
    return $self->{'_ref_root_id'};
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

=head2 gene_align_id

  Description : Getter/Setter for the gene_align_id field. This field would map
                to the gene_align / gene_align_member tables
  Returntype  : String
  Example     : my $aln_id = $tree->gene_align_id();
  Caller      : General

=cut

sub gene_align_id {
    my $self = shift;
    $self->{'_gene_align_id'} = shift if(@_);
    return $self->{'_gene_align_id'};
}


=head2 species_tree

  Description : Getter for the species-tree this gene tree is reconciled with
  Returntype  : Bio::EnsEMBL::Compara::SpeciesTree
  Example     : my $species_tree = $gene_tree->species_tree;
  Caller      : General

=cut

sub species_tree {
    my $self = shift;
    if (not defined $self->{_species_tree} and defined $self->adaptor) {
        $self->{_species_tree} = $self->adaptor->db->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->method_link_species_set_id, shift || 'default');
    }
    return $self->{_species_tree};
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
    return if $self->{_preloaded};

    if (not defined $self->{'_root'} and defined $self->{'_root_id'}) {
        my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
        $gtn_adaptor->{'_ref_tree'} = $self;
        $self->{'_root'} = $gtn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
        delete $gtn_adaptor->{'_ref_tree'};
    }
    $self->clear;

    my $all_nodes = $self->root->get_all_nodes;

    # Loads all the tags in one go
    $self->adaptor->db->get_GeneTreeNodeAdaptor->_load_tagvalues_multiple( $all_nodes );

    # For retro-compatibility, we need to fill in taxon_id and taxon_name
    my %cache_stns = ();
    foreach my $node (@$all_nodes) {
        if ($node->is_leaf) {
            $self->SUPER::add_Member($node) if UNIVERSAL::isa($node, 'Bio::EnsEMBL::Compara::GeneTreeMember');
        }
        next unless $node->has_tag('species_tree_node_id');
        my $stn_id = $node->get_value_for_tag('species_tree_node_id');
        if (exists $cache_stns{$stn_id}) {
            $node->{_species_tree_node} = $cache_stns{$stn_id};
        } else {
            $cache_stns{$stn_id} = $node->species_tree_node;
        }
        $node->add_tag('taxon_id', $node->species_tree_node->taxon_id);
        $node->add_tag('taxon_name', $node->species_tree_node->node_name);
    }

    # Loads all the gene members in one go
    $self->adaptor->db->get_GeneMemberAdaptor->load_all_from_seq_members( $self->get_all_Members );
    $self->{_preloaded} = 1;
}


=head2 alignment

  Arg [1]     : Bio::EnsEMBL::Compara::AlignedMemberSet $gene_align
  Description : Method to attach another multiple alignment of the
                same members the current tree.
  Returntype  : GeneTree
  Example     : $supertree->alignment($filtered_aln);
  Caller      : General

=cut

sub alignment {
    my $self = shift;
    my $other_gene_align = shift;

    if (not $other_gene_align) {
        $self->{_alignment} = $self->adaptor->db->get_GeneAlignAdaptor->fetch_by_dbID($self->gene_align_id()) unless $self->{_alignment};
        return $self->{_alignment};
    }

    assert_ref($other_gene_align, 'Bio::EnsEMBL::Compara::AlignedMemberSet');

    $self->preload;
    $self->seq_type($other_gene_align->seq_type);
    $self->gene_align_id($other_gene_align->dbID);
    $self->{_alignment} = $other_gene_align;

    # Gets the alignment
    my %cigars;
    foreach my $leaf (@{$other_gene_align->get_all_Members}) {
        $cigars{$leaf->seq_member_id} = $leaf->cigar_line;
    }

    my $self_members = $self->get_all_Members;
    die "The other alignment has a different size\n" if scalar(keys %cigars) != scalar(@$self_members);

    # Assigns it
    foreach my $leaf (@$self_members) {
        $leaf->cigar_line($cigars{$leaf->seq_member_id});
    }
}


=head2 alternative_trees

  Example     : $gene_tree->alternative_trees();
  Description : Returns all the alternative trees of the current tree
  Returntype  : Hashref of strings (clusterset_id) => Bio::EnsEMBL::Compara::GeneTree
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub alternative_trees {
    my $self = shift;

    if (not $self->{_alternative_trees}) {
        # Fetch all the other trees
        my $other_trees = $self->adaptor->fetch_all_linked_trees($self);
        # Make the hash for ourselves
        my $hash_trees = {};
        foreach my $t (@$other_trees) {
            $hash_trees->{$t->clusterset_id} = $t;
        }
        $self->{_alternative_trees} = { %$hash_trees };
        # And for every other tree
        $hash_trees->{$self->clusterset_id} = $self;
        foreach my $t (@$other_trees) {
            delete $hash_trees->{$t->clusterset_id};
            $t->{_alternative_trees} = { %$hash_trees };
            $hash_trees->{$t->clusterset_id} = $t;
        }
    }
    return $self->{_alternative_trees};
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

    unless (defined $self->adaptor) {
        warn '$self->adaptor() must be defined in expand_subtrees()';
    }
    unless ($self->tree_type eq 'supertree') {
        warn 'expand_subtrees() is only valid on super-trees';
    }

    # The tree is not loaded yet, we can do a fast-loading procedure
    if (not defined $self->{'_root'}) {

        # The current tree
        $self->preload;

        # Gets the subtrees
        my %subtrees;
        foreach my $subtree (@{$self->adaptor->fetch_subtrees($self)}) {
            $subtree->preload;
            $subtrees{$subtree->root->_parent_id} = $subtree->root;
        }

        # Attaches them
        foreach my $leaf (@{$self->root->get_all_leaves}) {
            die "All the leaves of a super-tree should be linkable to a tree" unless exists $subtrees{$leaf->node_id};
            $leaf->parent->add_child($subtrees{$leaf->node_id});
            $leaf->disavow_parent;
        }
    }

    # To update it at the next get_all_Members call
    delete $self->{'_member_array'};
    # Gets the global alignment
    $self->attach_alignment($self->adaptor->db->get_GeneAlignAdaptor->fetch_by_dbID($self->gene_align_id));
}


=head2 minimize_tree

  Example     : $tree->minimize_tree();
  Description : Minimizes the tree, i.e. removes the nodes that have a single child
  Returntype  : None
  Exceptions  : none
  Caller      : general

=cut

sub minimize_tree {
    my $self = shift;
    $self->{'_root'} = $self->{'_root'}->minimize_tree;
}


#######################
# MemberSet interface #
#######################

=head2 member_class

  Description: Returns the type of member used in the set
  Returntype : String: Bio::EnsEMBL::Compara::GeneTreeMember
  Caller     : Bio::EnsEMBL::Compara::MemberSet

=cut

sub member_class {
    return 'Bio::EnsEMBL::Compara::GeneTreeMember';
}


=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : General

=cut

sub _attr_to_copy_list {
    my $self = shift;
    my @sup_attr = $self->SUPER::_attr_to_copy_list();
    push @sup_attr, qw(_tree_type _member_type _clusterset_id _gene_align_id);
    return @sup_attr;
}


=head2 get_all_Members

  Description: Returns the list of all the GeneTreeMember of the tree
  Returntype : array reference of Bio::EnsEMBL::Compara::GeneTreeMember
  Caller     : General

=cut

sub get_all_Members {
    my ($self) = @_;

    unless (defined $self->{'_member_array'}) {
        $self->clear;
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


=head2 release_tree

  Overview   : Removes the to/from GeneTree reference to
               allow freeing memory
  Example    : $self->release_tree;
  Returntype : undef
  Exceptions : none
  Caller     : general

=cut

sub release_tree {
    my $self = shift;

    $self->root->release_tree;
    foreach my $member (@{$self->{'_member_array'}}) {
        delete $member->{'_tree'};
    }

    # Let's now release the alternative trees if they've been loaded
    return unless $self->{_alternative_trees};
    foreach my $other_tree (values %{$self->{_alternative_trees}}) {
        delete $other_tree->{_alternative_trees};
        $other_tree->release_tree;
    }
}



##########################
# GeneTreeNode interface #
##########################

# These methods used to be automatically created, but were missing from the Doxygen doc

=head2 get_all_nodes

  Example     : my $all_nodes = $root->get_all_nodes();
  Description : Returns this and all underlying sub nodes
  ReturnType  : listref of Bio::EnsEMBL::Compara::GeneTreeNode objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_nodes {
    my $self = shift;
    return $self->root->get_all_nodes;
}


=head2 get_all_leaves

 Description : creates the list of all the leaves in the tree
 Example     : my @leaves = @{$tree->get_all_leaves};
 ReturnType  : reference to list of GeneTreeNode/GeneTreeMember objects (all leaves)

=cut

sub get_all_leaves {
    my $self = shift;
    return $self->root->get_all_leaves;
}


=head2 get_all_sorted_leaves

  Arg [1]     : Bio::EnsEMBL::Compara::GeneTreeNode $top_leaf
  Arg [...]   : (optional) Bio::EnsEMBL::Compara::GeneTreeNode $secondary_priority_leaf
  Example     : my $sorted_leaves = $object->get_all_sorted_leaves($human_leaf);
  Example     : my $sorted_leaves = $object->get_all_sorted_leaves($human_leaf, $mouse_leaf);
  Description : Sorts the tree such as $top_leaf is the first leave and returns
                all the other leaves in the order defined by the tree.
                It is possible to define as many secondary top leaves as you require
                to sort other branches of the tree. The priority to sort the trees
                is defined by the order in which you specify the leaves.
  Returntype  : listref of Bio::EnsEMBL::Compara::GeneTreeNode (all sorted leaves)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_sorted_leaves {
    my $self = shift;
    return $self->root->get_all_sorted_leaves(@_);
}


=head2 get_leaf_by_Member

  Arg [1]     : Member: the member to search in the tree
  Example     : my $leaf = $brca2_tree->get_leaf_by_Member($brca2_peptide)
  Description : Returns the leaf that corresponds to the member given as argument
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeMember object
  Exceptions  :
  Caller      : general
  Status      : stable

=cut

sub get_leaf_by_Member {
    my ($self, $member) = @_;
    return $self->root->get_leaf_by_Member($member);
}


sub find_leaf_by_node_id {
    my $self = shift;
    return $self->root->find_leaf_by_node_id(@_);
}


sub find_leaf_by_name {
    my $self = shift;
    return $self->root->find_leaf_by_name(@_);
}


sub find_node_by_node_id {
    my $self = shift;
    return $self->root->find_node_by_node_id(@_);
}

sub find_node_by_name {
    my $self = shift;
    return $self->root->find_node_by_name(@_);
}


=head2 newick_format

  Arg [1]     : string $format_mode
  Example     : $gene_tree->newick_format("full");
  Description : Prints this tree in Newick format. Several modes are
                available: full, display_label_composite, simple, species,
                species_short_name, ncbi_taxon, ncbi_name and phylip
  Returntype  : string
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub newick_format {
    my $self = shift;
    return $self->root->newick_format(@_);
}


=head2 nhx_format

  Arg [1]     : string $format_mode
  Example     : $gene_tree->nhx_format("full");
  Description : Prints this tree in NHX format. Several modes are
                member_id_taxon_id, protein_id, transcript_id, gene_id,
                full, full_web, display_label, display_label_composite,
                treebest_ortho, simple, phylip
  Returntype  : string
  Exceptions  :
  Caller      : general
  Status      : Stable

=cut

sub nhx_format {
    my $self = shift;
    return $self->root->nhx_format(@_);
}


=head2 string_tree

  Arg [1]     : int $scale
  Example     : my $str = $gene_tree->string_tree(100);
  Description : Returns a string representing this tree in ASCII format.
                The scale is used to define the width of the tree in the output
  Returntype  : undef
  Exceptions  :
  Caller      : general
  Status      : At risk (as the output might change)

=cut

sub string_tree {
    my $self = shift;
    return $self->root->string_tree(@_);
}


=head2 print_tree

  Arg [1]     : int $scale
  Example     : $gene_tree->print_tree(100);
  Description : Prints this tree in ASCII format. The scale is used to define
                the width of the tree in the output
  Returntype  : undef
  Exceptions  :
  Caller      : general
  Status      : At risk (as the output might change)

=cut

sub print_tree {
    my $self = shift;
    return $self->root->print_tree(@_);
}


1;

