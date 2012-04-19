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

Adaptor for a GeneTree object (individual nodes will be internally retrieved
with the GeneTreeNodeAdaptor).

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::TagAdaptor

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

use Bio::EnsEMBL::Utils::Argument qw(rearrange);

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
             : int: the root_id of the clusterset node
               NB: It currently gives the same partition of the data as member_type
               NB: The definition of this argument is unstable and might change
                   in the future
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

    my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
    if (defined $mlss_id) {
        push @constraint, '(gtr.method_link_species_set_id = ?)';
        $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    }

    if (defined $clusterset_id) {
        push @constraint, '(gtr.clusterset_id = ?)';
        $self->bind_param_generic_fetch($clusterset_id, SQL_INTEGER);
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
    return $self->generic_fetch('gtr.stable_id = ?')->[0];
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
    return $self->generic_fetch('gtr.root_id = ?')->[0];
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
    return $self->generic_fetch('gtr.root_id = ?')->[0];
}


=head2 fetch_all_by_Member

  Arg[1]     : Member or member_id
  Arg [-METHOD_LINK_SPECIES_SET] (opt)
             : MethodLinkSpeciesSet or int: either the object or its dbID
  Arg [-CLUSTERSET_ID] (opt)
             : int: the root_id of the clusterset node
               NB: The definition of this argument is unstable and might change
                   in the future
  Example    : $all_trees = $genetree_adaptor->fetch_all_by_Member($member);
  Description: Fetches from the database all the gene trees that contains this member
               If the member is not an ENSEMBLGENE, it has to be canoncal, otherwise,
                 the function would return undef
  Returntype : arrayref of Bio::EnsEMBL::Compara::GeneTree
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Member {
    my ($self, $member, @args) = @_;
    my ($clusterset_id, $mlss) = rearrange([qw(CLUSTERSET_ID METHOD_LINK_SPECIES_SET)], @args);

    # Discard the UNIPROT members
    return if (ref($member) and not ($member->source_name =~ 'ENSEMBL'));

    my $join = [[['gene_tree_node', 'gtn'], 'gtn.root_id = gtr.root_id'], [['gene_tree_member', 'gtm'], 'gtn.node_id = gtm.node_id'], [['member', 'm'], 'gtm.member_id = m.member_id']];
    my $constraint = '((m.member_id = ?) OR (m.gene_member_id = ?))';
    
    my $member_id = (ref($member) ? $member->dbID : $member);
    $self->bind_param_generic_fetch($member_id, SQL_INTEGER);
    $self->bind_param_generic_fetch($member_id, SQL_INTEGER);
    
    my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
    if (defined $mlss_id) {
        $constraint .= ' AND (gtr.method_link_species_set_id = ?)';
        $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    }
    if (defined $clusterset_id) {
        $constraint .= ' AND (gtr.clusterset_id = ?)';
        $self->bind_param_generic_fetch($clusterset_id, SQL_INTEGER);
    }

    return $self->generic_fetch($constraint, $join);
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

    my $tree_id = (ref($tree) ? $tree->root_id : $tree);

    my $join = [[['gene_tree_node', 'gtn1'], 'gtn1.root_id = gtr.root_id'], [['gene_tree_node', 'gtn2'], 'gtn1.node_id = gtn2.parent_id']];
    my $constraint = "(gtn2.root_id = gtn2.node_id) AND (gtn2.root_id = ?)";
    
    $self->bind_param_generic_fetch($tree_id, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join)->[0];
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

    my $tree_id = (ref($tree) ? $tree->root_id : $tree);

    my $join = [[['gene_tree_node', 'gtn2'], 'gtn2.node_id = gtr.root_id'], [['gene_tree_node', 'gtn1'], 'gtn1.node_id = gtn2.parent_id']];
    my $constraint = "(gtn1.root_id = ?) AND (gtn1.left_index = (gtn1.right_index - 1))";

    $self->bind_param_generic_fetch($tree_id, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join);
}


#
# STORE methods
###########################

sub store {
    my ($self, $tree) = @_;

    # Firstly, store the nodes
    $tree->root->store();

    # Secondly, the tree itself
    my $sth = $self->prepare('INSERT IGNORE INTO gene_tree_root (root_id) VALUES (?)');
    $sth->execute($tree->root_id);

    $sth = $self->prepare('UPDATE gene_tree_root SET tree_type = ?, member_type = ?, clusterset_id = ?, method_link_species_set_id = ?, stable_id = ?, version = ? WHERE root_id = ?'),
    $sth->execute($tree->tree_type, $tree->member_type, $tree->clusterset_id, $tree->method_link_species_set_id, $tree->stable_id, $tree->version, $tree->root_id);
    
    $tree->adaptor($self);

    return $tree->root_id;
}


#
# Virtual methods from TagAdaptor
###################################

sub _tag_capabilities {
    return ('gene_tree_root_tag', undef, 'root_id', 'root_id');
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
