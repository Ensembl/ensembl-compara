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

Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor

=head1 DESCRIPTION

Generic adaptor for a tree, later derived as ProteinTreeAdaptor or NCTreeAdaptor

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor

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

package Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor;

use strict;
no strict 'refs';

use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::GeneTree;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');


sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->_prepare_sql_commands(
        "INSERT" => "INSERT INTO gene_tree_root (tree_type, member_type, clusterset_id, method_link_species_set_id, stable_id, version, root_id) VALUES (?,?,?,?,?,?)",
        "UPDATE" => "UPDATE gene_tree_root SET tree_type = ?, member_type = ?, clusterset_id = ?, method_link_species_set_id = ?, stable_id = ?, version = ? WHERE root_id = ?",
    );

    return $self;
}




#
# FETCH methods
###########################

=head2 fetch_all

  Example    : $all_trees = $proteintree_adaptor->fetch_all(1);

  Description: Fetches from the database all the protein trees
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions :
  Caller     :
=cut

sub fetch_all {
    my ($self, @args) = @_;
    my ($clusterset_id, $mlss_id, $tree_type, $member_type)
        = rearrange([qw(CLUSTERSET_ID METHOD_LINK_SPECIES_SET_ID TREE_TYPE MEMBER_TYPE)], @args);

    my @constraint = ();
    push @constraint, "clusterset_id = ${clusterset_id}" if defined $clusterset_id;
    push @constraint, "method_link_species_set_id = ${mlss_id}" if defined $mlss_id;
    push @constraint, "tree_type = ${tree_type}" if defined $tree_type;
    push @constraint, "member_type = ${member_type}" if defined $member_type;

    return $self->_generic_fetch(join(" AND ", @constraint));
}



sub fetch_all_roots {
    my $self = shift;
    deprecate('Use fetch_all(-tree_type=>"clusterset") instead (possibly with a member_type constraint)');
    return $self->fetch_all(-tree_type => "clusterset");
}





=head2 fetch_by_stable_id

  Arg[1]     : string $protein_tree_stable_id
  Example    : $protein_tree = $proteintree_adaptor->fetch_by_stable_id("ENSGT00590000083078");

  Description: Fetches from the database the protein_tree for that stable ID
  Returntype : Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions : returns undef if $stable_id is not found.
  Caller     :

=cut

sub fetch_by_stable_id {
    my ($self, $stable_id) = @_;

    return $self->_unique_generic_fetch("stable_id='$stable_id'");
}

sub fetch_by_root_id {
    my ($self, $root_id) = @_;

    return $self->_unique_generic_fetch("root_id=$root_id");
}


sub fetch_parent_tree {
    my ($self, $tree) = @_;

    return $self->fetch_by_root_id($tree->root->parent->_root_id) if defined $tree->root->parent;
}

# SELECT gtr.* FROM gene_tree_node gtn1 JOIN gene_tree_node gtn2 ON gtn1.node_id=gtn2.parent_id JOIN gene_tree_root gtr ON gtn2.node_id=gtr.root_id WHERE gtn1.root_id = ? AND gtn1.left_index=gtn1.right_index-1
sub fetch_subtrees {
    my ($self, $tree) = @_;

    my @subtrees;
    foreach my $leaf ($tree->root->get_all_leaves) {
        #push @subtrees, @{
        #foreach $self->db->get_GeneTreeNodeAdaptor->fetch_all_children_for_node($leaf)};
    }
    return \@subtrees;

}

sub fetch_by_Member {
    my ($self, $member) = @_;

    # Discard the UNIPROT members
    return unless $member->source_name =~ "ENSEMBL";

    # Looks for the most
    my $can_member = $member->get_canonical_peptide_Member($member);
       $can_member = $member->get_canonical_transcript_Member($member) unless defined $can_member;
    return unless defined $can_member;
    my $member_id = $can_member->dbID;

    # Other solution:
    # - go to the gene_member
    # - use two joins to the member table
}


# STORE methods
###########################

sub store {
    my ($self, $tree) = @_;

    # Firstly, store the nodes
    # FIXME
    my $root_id;

    # Secondly, the tree itself
    my $sth;
    if ($tree->adaptor and $tree->adaptor->isa('Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor') and $tree->adaptor eq $self) {
        $sth = $self->{'_sth_cache'}{'UPDATE'};
    } else {
        $tree->adaptor($self);
        $sth = $self->{'_sth_cache'}{'INSERT'};
    }
    $sth->execute($tree->tree_type, $tree->member_type, $tree->clusterset_id, $tree->method_link_species_set_id, $tree->stable_id, $tree->version, $root_id);

    return $root_id;
}


#
# Virtual methods from TagAdaptor
###################################

sub _tag_capabilities {
    return ("gene_tree_root_tag", undef, "root_id", "root_id");
}


#
# Virtual methods from BaseAdaptor
####################################

sub _tables {

    return (['gene_tree_root', 'gtr'])
}

sub _columns {

    return qw (
        gtr.root_id
        gtr.tree_type
        gtr.member_type
        gtr.clusterset_id
        gtr.method_link_species_set_id
        gtr.stable_id
        gtr.version
    );
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  my @tree_list = ();

  while(my $rowhash = $sth->fetchrow_hashref) {

    # a new GeneTree object
    my $tree = new Bio::EnsEMBL::Compara::GeneTree;
    foreach my $attr (qw(root_id tree_type member_type clusterset_id method_link_species_set_id stable_id version)) {
        $tree->$attr($rowhash->{$attr});
    }
    $tree->adaptor($self);

    push @tree_list, $tree;
  }

  return \@tree_list;
}


1;
