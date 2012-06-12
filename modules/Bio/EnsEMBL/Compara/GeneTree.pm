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


=head2 member_class

  Description: Returns the type of member used in the set
  Returntype : String: Bio::EnsEMBL::Compara::GeneTreeMember
  Caller     : general
  Status     : Stable

=cut

sub member_class {
    return 'Bio::EnsEMBL::Compara::GeneTreeMember';
}


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

  Description: Returns a copy of $self. All the members are themselves copied
  Returntype : Bio::EnsEMBL::Compara::GeneTree
  Caller     : general
  Status     : Stable

=cut

sub deep_copy {
    my $self = shift;
    my $copy = $self->SUPER::deep_copy();
    foreach my $attr (qw(tree_type member_type clusterset_id)) {
        $copy->$attr($self->$attr);
    }
    return $copy;
}



=head2 DESTROY()

  Description : Deletes the reference to the root node and breaks
                the circular reference.
  Returntype  : None
  Exceptions  : None
  Status      : System
  
=cut

sub DESTROY {
    my $self = shift;
    delete $self->{'_root'};
}


=head2 tree_type()

  Description : Getter/Setter for the tree_type field. This field can
                currently be 'tree', 'supertree' or 'clusterset'
  Returntype  : String
  Exceptions  : None
  Example     : my $type = $tree->tree_type();
  Status      : Stable  
  
=cut

sub tree_type {
    my $self = shift;
    $self->{'_tree_type'} = shift if(@_);
    return $self->{'_tree_type'};
}


=head2 member_type()

  Description : Getter/Setter for the member_type field. This field can
                currently be 'ncrna' or 'protein'
  Returntype  : String
  Exceptions  : None
  Example     : my $type = $tree->member_type();
  Status      : Stable  
  
=cut

sub member_type {
    my $self = shift;
    $self->{'_member_type'} = shift if(@_);
    return $self->{'_member_type'};
}


sub clusterset_id {
    my $self = shift;
    $self->{'_clusterset_id'} = shift if(@_);
    return $self->{'_clusterset_id'};
}



=head2 root()

  Description : Getter for the root node of the tree. This returns an
                object fetch from the database if root_id is defined.
                Otherwise, it will create a new GeneTreeNode object.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions  : None
  Example     : my $root_node = $tree->root();
  Status      : Stable
  
=cut

sub root {
    my $self = shift;

    if (not defined $self->{'_root'}) {
        if (defined $self->{'_root_id'} and defined $self->{'_adaptor'}) {
            # Loads all the nodes in one go
            my $gtn_adaptor = $self->{'_adaptor'}->db->get_GeneTreeNodeAdaptor;
            $gtn_adaptor->{'_ref_tree'} = $self;
            $self->{'_root'} = $gtn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
            delete $gtn_adaptor->{'_ref_tree'};

            # Loads all the gene members in one go
            my %leaves;
            foreach my $pm (@{$self->{'_root'}->get_all_leaves}) {
                $leaves{$pm->gene_member_id} = $pm if UNIVERSAL::isa($pm, 'Bio::EnsEMBL::Compara::GeneTreeMember');
            }
            my @m_ids = keys(%leaves);
            my $all_gm = $self->{'_adaptor'}->db->get_MemberAdaptor->fetch_all_by_dbID_list(\@m_ids);
            foreach my $gm (@$all_gm) {
                $leaves{$gm->dbID}->gene_member($gm);
            }
        } else {
            # Creates a new GeneTreeNode object
            $self->{'_root'} = new Bio::EnsEMBL::Compara::GeneTreeNode;
            $self->{'_root'}->tree($self);
        }
    }
    return $self->{'_root'};
}



=head2 root_id()

  Description : Getter/Setter for the root_id of the root node of the tree.
                This is internally synchronised with the root() method and
                vice-versa to ensure consistency.
  Returntype  : Integer
  Exceptions  : None
  Example     : my $root_node_id = $tree->root_id();
  Status      : Stable
  
=cut

sub root_id {
    my $self = shift;
    return $self->{'_root_id'};
}

=head2 get_all_Members

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::GeneTreeMember
  Exceptions : 
  Caller     : 

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

sub member_class {
    return 'Bio::EnsEMBL::Compara::GeneTreeMember';
}

=head2 add_Member

  Arg [1]    : GeneTreeMember
  Example    : 
  Description: Add a new GeneTreeMember to this set
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : general
  Status     : Stable

=cut

sub add_Member {
    my ($self, $member) = @_;
    assert_ref($member, 'Bio::EnsEMBL::Compara::GeneTreeMember');
    $self->root->add_child($member);
    $member->tree($self);
    $self->SUPER::add_Member($member);
} 


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

