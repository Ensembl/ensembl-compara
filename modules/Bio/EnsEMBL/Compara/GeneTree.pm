=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 VERSION

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


=head2

  Description : Getter for the species-tree this gene tree is reconciled with
  Returntype  : Bio::EnsEMBL::Compara::SpeciesTree
  Example     : my $species_tree = $gene_tree->species_tree;
  Caller      : General

=cut

sub species_tree {
    my $self = shift;
    if (not defined $self->{_species_tree} and defined $self->adaptor) {
        $self->{_species_tree} = $self->adaptor->db->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->method_link_species_set_id, 'default');
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

    if (not defined $self->{'_root'} and defined $self->{'_root_id'}) {
        my $gtn_adaptor = $self->adaptor->db->get_GeneTreeNodeAdaptor;
        $gtn_adaptor->{'_ref_tree'} = $self;
        $self->{'_root'} = $gtn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
        delete $gtn_adaptor->{'_ref_tree'};
    }

    # Loads all the tags in one go
    $self->adaptor->db->get_GeneTreeNodeAdaptor->_load_tagvalues_multiple( $self->root->get_all_nodes );

    # For retro-compatibility, we need to fill in taxon_id and taxon_name
    my %cache_stns = ();
    foreach my $node (@{$self->root->get_all_nodes}) {
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
    my %leaves;
    foreach my $pm (@{$self->root->get_all_leaves}) {
        $leaves{$pm->gene_member_id} = $pm if UNIVERSAL::isa($pm, 'Bio::EnsEMBL::Compara::GeneTreeMember');
    }
    my @m_ids = keys(%leaves);
    my $all_gm = $self->adaptor->db->get_GeneMemberAdaptor->fetch_all_by_dbID_list(\@m_ids);
    foreach my $gm (@$all_gm) {
        $leaves{$gm->dbID}->gene_member($gm);
    }
}


=head2 attach_alignment

  Arg [1]     : Bio::EnsEMBL::Compara::AlignedMemberSet $gene_align
  Description : Method to attach another multiple alignment of the
                same members the current tree.
  Returntype  : GeneTree
  Example     : $supertree->attach_alignment($filtered_aln);
  Caller      : General

=cut

sub attach_alignment {
    my $self = shift;
    my $other_gene_align = shift;

    assert_ref($other_gene_align, 'Bio::EnsEMBL::Compara::AlignedMemberSet');

    $self->preload;
    $self->seq_type($other_gene_align->seq_type);

    # Gets the alignment
    my %cigars;
    foreach my $leaf (@{$other_gene_align->get_all_Members}) {
        $cigars{$leaf->member_id} = $leaf->cigar_line;
    }

    die "The other alignment has a different size\n" if scalar(keys %cigars) != scalar(@{$self->get_all_Members});

    # Assigns it
    foreach my $leaf (@{$self->get_all_Members}) {
        $leaf->cigar_line($cigars{$leaf->member_id});
    }
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
}



########
# Misc #
########

# Dynamic definition of functions to allow NestedSet methods work with GeneTrees
{
    no strict 'refs';
    foreach my $func_name (qw(get_all_nodes get_all_leaves get_all_sorted_leaves
                              find_leaf_by_node_id find_leaf_by_name find_node_by_node_id
                              find_node_by_name remove_nodes build_leftright_indexing flatten_tree
                              newick_format nhx_format string_tree print_tree
                            )) {
        my $full_name = "Bio::EnsEMBL::Compara::GeneTree::$func_name";
        *$full_name = sub {
            my $self = shift;
            my $ret = $self->root->$func_name(@_);
            return $ret;
        };
        #    print STDERR "REDEFINE $func_name\n";
    }
}

1;

