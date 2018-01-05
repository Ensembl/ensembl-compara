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

use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;
use Bio::EnsEMBL::Compara::Utils::Preloader;

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


=head2 species_tree_root_id

  Description : Getter/Setter for the species_tree_root_id field. This field would map
                to the gene_align / gene_align_member tables
  Returntype  : String
  Example     : my $aln_id = $tree->species_tree_root_id();
  Caller      : General

=cut

sub species_tree_root_id {
    my $self = shift;
    $self->{'_species_tree_root_id'} = shift if(@_);
    return $self->{'_species_tree_root_id'};
}


=head2 species_tree

  Description : Getter for the species-tree this gene tree is reconciled with
  Returntype  : Bio::EnsEMBL::Compara::SpeciesTree
  Example     : my $species_tree = $gene_tree->species_tree;
  Caller      : General

=cut

sub species_tree {
    my $self = shift;

    unless ($self->{'_species_tree'}) {
        if (@_) {
            $self->{'_species_tree'} = shift;
        } elsif ($self->{'_species_tree_root_id'}) {
            $self->{'_species_tree'} = $self->adaptor->db->get_SpeciesTreeAdaptor->fetch_by_root_id( $self->{'_species_tree_root_id'} );
        } else {
            $self->{'_species_tree'} = $self->method_link_species_set->species_tree(shift || 'default');
        }
    }
    return $self->{'_species_tree'};
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
    my $no_preload = shift;

    if (not defined $self->{'_root'}) {
        if (defined $self->{'_root_id'} and defined $self->adaptor) {
            if ($no_preload) {
                # Only load 1 node
                my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
                $self->{'_root'} = $gtn_adaptor->fetch_node_by_node_id($self->{'_root_id'});
            } else {
                # Loads all the nodes in one go
                $self->preload;
            }

        } else {
            # Creates a new GeneTreeNode object
            $self->{'_root'} = new Bio::EnsEMBL::Compara::GeneTreeNode;
            $self->{'_root'}->tree($self);
        }
    }
    return $self->{'_root'};
}


=head2 preload

  Arg [1]     : (optional) Arrayref of strings $species. If given, genes that
                do not belong to those species are pruned of the tree
  Description : Method to load all the tree data in one go. This currently
                includes (if not loaded yet) the nodes, the tags, and the
                gene Members associated with the leaves.
  Returntype  : node
  Example     : $tree->preload();
                $tree->preload(-PRUNE_SPECIES => ['human', 'mouse', 'chicken']);
  Caller      : General

=cut

sub preload {
    my $self = shift;

    return unless defined $self->adaptor;
    return if $self->{_preloaded};

    my ($prune_subtree, $prune_species, $prune_taxa) =
        rearrange([qw(PRUNE_SUBTREE PRUNE_SPECIES PRUNE_TAXA)], @_);

    # Preload the tree structure
    if (not defined $self->{'_root'} and defined $self->{'_root_id'}) {
        my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
        $gtn_adaptor->{'_ref_tree'} = $self;
        if ($prune_subtree and ($prune_subtree != $self->{'_root_id'})) {
            $self->{'_root'} = $gtn_adaptor->fetch_tree_at_node_id($prune_subtree);
            warn "Could not fetch a subtree from node_id '$prune_subtree'\n" unless $self->{'_root'};
            $self->{'_pruned'} = 1;
        } else {
            $self->{'_root'} = $gtn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
            unless ($self->{'_root'}) {
                warn "Could not fetch a tree with the root_id '".$self->{'_root_id'}."'\n";
                $self->{'_root'} = $gtn_adaptor->fetch_node_by_node_id($self->{'_root_id'});
                warn "No node with node_id '".$self->{'_root_id'}."'\n" unless $self->{'_root'};
            }
        }
        delete $gtn_adaptor->{'_ref_tree'};
    } elsif (not defined $self->{'_root'}) {
        die "This tree has no root node, and no root_id. This is not valid.\n";
    }
    $self->clear;
    return unless $self->{'_root'};

    $self->{_preloaded} = 1;
    return if $self->tree_type eq 'clusterset';

    # And prune it immediately
    if ($prune_species || $prune_taxa) {
        my $genome_dbs = $self->adaptor->db->get_GenomeDBAdaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => $prune_species, -TAXON_LIST => $prune_taxa);
        my %genome_db_ids = map {$_->dbID => 1} @$genome_dbs;
        my @to_delete;
        my $root = $self->root;
        foreach my $leaf (@{$root->get_all_leaves}) {
            if (UNIVERSAL::isa($leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember') and not exists $genome_db_ids{$leaf->genome_db_id}) {
                my $internal_node = $leaf->parent;
                die "All the leaves are lost after pruning the tree !\n" if not defined $internal_node;     # $leaf was the last leaf of the tree. The tree is now empty
                $leaf->disavow_parent;
                # $parent
                # +--- XXX
                # `--- $internal_node
                #      +--- $leaf
                #      `--- $sibling
                #           +--- $child1
                #           `--- $child2
                my $sibling = $internal_node->children->[0];
                if ($internal_node->node_id == $root->node_id) {
                    $root = $sibling;
                    $sibling->disavow_parent;
                } else {
                    $internal_node->parent->add_child($sibling, $sibling->distance_to_parent+$internal_node->distance_to_parent);
                    $internal_node->disavow_parent;
                }
                $self->{'_pruned'} = 1;
            }
        }
        $self->{'_root'} = $root;
    }

    my $all_nodes = $self->root->get_all_nodes;

    # Loads all the tags in one go
    $self->adaptor->db->get_GeneTreeNodeAdaptor->_load_tagvalues_multiple( $all_nodes );

    # We can't use _load_and_attach_all because _species_tree_node_id
    # is not stored as a key in the hash (it's a tag)
    my $stn_id_lookup = $self->species_tree->get_node_id_2_node_hash();
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_NCBITaxon($self->adaptor->db->get_NCBITaxonAdaptor, [values %$stn_id_lookup]);
    foreach my $node (@$all_nodes) {
        if ($node->is_leaf) {
            $self->SUPER::add_Member($node) if UNIVERSAL::isa($node, 'Bio::EnsEMBL::Compara::GeneTreeMember');
        }
        # This is like GeneTreeNode::species_tree_node() but using the lookup
        $node->{_species_tree_node} = $stn_id_lookup->{$node->_species_tree_node_id} if $node->_species_tree_node_id;
        # This is like GeneTreeNode::lost_taxa() but using the lookup
        $node->{_lost_species_tree_nodes} = [map {$stn_id_lookup->{$_}} @{ $node->get_all_values_for_tag('lost_species_tree_node_id') }];
    }

    # Loads all the gene members in one go
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->adaptor->db->get_GeneMemberAdaptor, $self->get_all_Members);
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

    assert_ref($other_gene_align, 'Bio::EnsEMBL::Compara::AlignedMemberSet', 'other_gene_align');

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

        # Gets the subtrees
        my %subtrees;
        foreach my $subtree (@{$self->adaptor->fetch_subtrees($self)}) {
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
    $self->alignment($self->adaptor->db->get_GeneAlignAdaptor->fetch_by_dbID($self->gene_align_id));
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


=head2 get_alignment_of_homologues

  Arg [1]     : Bio::EnsEMBL::Compara::Member $query_gene
  Arg [2]     : String $method_link_type (optional). By default, the method uses all the
                homologues. Use this argument to restrict the list to ENSEMBL_ORTHOLOGUES,
                ENSEMBL_PARALOGUES, or ENSEMBL_HOMEOELOGUES
  Arg [3]     : Arrayref of strings $species. The list of species to keep in the alignment
  Example     : $gene_tree->get_alignment_of_homologues($brca2_gene_member);
  Description : Creates a new instance of AlignedMemberSet that is the pruned version
                of the tree's alignment, but restricted to the homologues of a query gene.
                The alignment can be further restricted to a list of species.
  Returntype  : Bio::EnsEMBL::Compara::AlignedMemberSet
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_alignment_of_homologues {
    my ($self, $query_gene, $method_link_type, $species) = @_;

    assert_ref($query_gene, 'Bio::EnsEMBL::Compara::Member', 'query_gene');
    assert_ref($species, 'ARRAY', 'species') if $species;

    # List the homologues
    my $homologies = $self->adaptor->db->get_HomologyAdaptor->fetch_all_by_Member($query_gene, -METHOD_LINK_TYPE => $method_link_type);
    my @homologous_genes = map {$_->get_all_Members()->[1]} @$homologies;

    if ($species) {
        my $genome_db_adaptor = $self->adaptor->db->get_GenomeDBAdaptor;
        my $genome_dbs = $self->adaptor->db->get_GenomeDBAdaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => $species);
        my %genome_db_ids = map {$_->dbID => 1} @$genome_dbs;
        @homologous_genes = grep {$genome_db_ids{$_->genome_db_id}} @homologous_genes;
    }

    my %members_to_keep = map {$_->dbID => 1} @homologous_genes;
    $members_to_keep{$query_gene->isa('Bio::EnsEMBL::Compara::GeneMember') ? $query_gene->canonical_member_id : $query_gene->dbID} = 1;

    # Create a new AlignedMemberSet object with the same properties
    my $alignment = $self->alignment;

    my $new_aligment = new Bio::EnsEMBL::Compara::AlignedMemberSet();
    foreach my $attr ($alignment->_attr_to_copy_list) {
        $new_aligment->{$attr} = $alignment->{$attr};
    }

    # Add the relevant members
    foreach my $member (@{$alignment->get_all_Members()}) {
        $new_aligment->add_Member($member) if $members_to_keep{$member->dbID};
    }

    return $new_aligment;
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
    push @sup_attr, qw(_tree_type _member_type _clusterset_id _gene_align_id _species_tree_root_id);
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
        if ($self->{_preloaded}) {
            $self->clear;
            foreach my $leaf (@{$self->root->get_all_leaves}) {
                $self->SUPER::add_Member($leaf) if UNIVERSAL::isa($leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember');
            }
        } else {
            $self->preload;
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
    assert_ref($member, 'Bio::EnsEMBL::Compara::GeneTreeMember', 'member');
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

    if ($self->{'_root'}) {
        $self->{'_root'}->release_tree;
    }
    foreach my $member (@{$self->{'_member_array'}}) {
        delete $member->{'_tree'};
    }

    # Release all the references to the members
    $self->clear;
    delete $self->{_preloaded};

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
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($self->adaptor->db->get_DnaFragAdaptor, $self->get_all_Members);
    return $self->root->print_tree(@_);
}


1;

