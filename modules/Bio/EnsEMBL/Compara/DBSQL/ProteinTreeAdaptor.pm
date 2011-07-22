=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

Specialization of Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor for proteins

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor
   +- Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor;

use strict;

use base ('Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor');


sub _get_table_prefix {
	return "protein";
}

sub _get_canonical_Member {
  my $self = shift;
  my $member = shift;

  return $member->get_canonical_peptide_Member;
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

  my $root_id = $self->db->get_ProteinTreeStableIdAdaptor->fetch_node_id_by_stable_id($stable_id);
  return undef unless (defined $root_id);

  my $protein_tree = $self->fetch_node_by_node_id($root_id);

  return $protein_tree;
}



# Fetch data from stable_id table -- similar in concept to fetching sequence from member
sub _fetch_stable_id_by_node_id {
  my ($self, $node_id) = @_;
  return $self->db->get_ProteinTreeStableIdAdaptor->fetch_by_node_id($node_id);
}


##########################################################
#
# explicit method forwarding to MemberAdaptor
#
##########################################################

sub fetch_gene_for_peptide_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_gene_for_peptide_member_id(@_);
}

sub fetch_peptides_for_gene_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_peptides_for_gene_member_id(@_);
}

sub fetch_longest_peptide_member_for_gene_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_longest_peptide_member_for_gene_member_id(@_);
}

1
