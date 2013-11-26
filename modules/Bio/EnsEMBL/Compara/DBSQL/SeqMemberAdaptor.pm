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

Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor

=head1 DESCRIPTION

Adaptor to retrieve SeqMember objects.
Most of the methods are shared with the GeneMemberAdaptor.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor

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


package Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning stack_trace_dump deprecate);
use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor);








#
# GLOBAL METHODS
#
#####################















































































#
# SeqMember only methods
#
############################


=head2 fetch_all_by_sequence_id

  Arg [1]    : int sequence_id
  Example    : @pepMembers = @{$SeqMemberAdaptor->fetch_all_by_sequence_id($seq_id)};
  Description: given a sequence_id, fetches all sequence members for this sequence
  Returntype : array ref of Bio::EnsEMBL::Compara::SeqMember objects
  Exceptions :
  Caller     : general


=cut

sub fetch_all_by_sequence_id {
    my ($self, $sequence_id) = @_;

    $self->bind_param_generic_fetch($sequence_id, SQL_INTEGER);
    return $self->generic_fetch('m.sequence_id = ?');
}





=head2 fetch_all_by_gene_member_id

  Arg [1]    : int member_id of a gene member
  Example    : @pepMembers = @{$SeqMemberAdaptor->fetch_all_by_gene_member_id($gene_member_id)};
  Description: given a member_id of a gene member, fetches all sequence members for this gene
  Returntype : array ref of Bio::EnsEMBL::Compara::SeqMember objects
  Exceptions : $gene_member_id not defined
  Caller     : general

=cut

sub fetch_all_by_gene_member_id {
  my ($self, $gene_member_id) = @_;

  throw() unless (defined $gene_member_id);

    $self->bind_param_generic_fetch($gene_member_id, SQL_INTEGER);
    return $self->generic_fetch('m.gene_member_id = ?');
}




=head2 fetch_all_canonical_by_source_genome_db_id

  Arg [1]    : string source_name
  Arg [1]    : int genome_db_id of a a species
  Example    : @canMembers = @{$SeqMemberAdaptor->fetch_all_canonical_by_source_genome_db_id('ENSEMBLPEP', 90)};
  Description: fetches all the canonical members of given source_name and species
  Returntype : array ref of Bio::EnsEMBL::Compara::SeqMember objects
  Exceptions : arguments not defined
  Caller     : general

=cut

sub fetch_all_canonical_by_source_genome_db_id {
  my ($self,$source_name,$genome_db_id) = @_;

  throw("source_name and genome_db_id args are required") 
    unless($source_name && $genome_db_id);

    my $join = [[['member', 'mg'], 'mg.canonical_member_id = m.member_id']];

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND mg.genome_db_id = ?', $join);
}






=head2 fetch_canonical_for_gene_member_id

  Arg [1]    : int member_id of a gene member
  Example    : $members = $memberAdaptor->fetch_canonical_for_gene_member_id($gene_member_id);
  Description: given a member_id of a gene member,
               fetches the canonical peptide / transcript member for this gene
  Returntype : Bio::EnsEMBL::Compara::SeqMember object
  Exceptions :
  Caller     : general

=cut

sub fetch_canonical_for_gene_member_id {
    my ($self, $gene_member_id) = @_;

    throw() unless (defined $gene_member_id);

    my $constraint = 'mg.member_id = ?';
    my $join = [[['member', 'mg'], 'm.member_id = mg.canonical_member_id']];

    $self->bind_param_generic_fetch($gene_member_id, SQL_INTEGER);
    return $self->generic_fetch_one($constraint, $join);
}







#
# GeneMember only methods
############################









#
# INTERNAL METHODS
#
###################



sub create_instance_from_rowhash {
	my ($self, $rowhash) = @_;
	
	my $obj = $self->SUPER::create_instance_from_rowhash($rowhash);
	bless $obj, 'Bio::EnsEMBL::Compara::SeqMember';
	return $obj;
}







#
# STORE METHODS
#
################


sub store {
    my ($self, $member) = @_;
   
    assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember');
    return $self->SUPER::store($member);
}









sub update_sequence {
  my ($self, $member) = @_;

  return 0 unless($member);
  unless($member->dbID) {
    throw("MemberAdapter::update_sequence member must have valid dbID\n");
  }
  unless(defined($member->sequence)) {
    warning("MemberAdapter::update_sequence with undefined sequence\n");
  }

  if($member->sequence_id) {
    my $sth = $self->prepare("UPDATE sequence SET sequence = ?, length=? WHERE sequence_id = ?");
    $sth->execute($member->sequence, $member->seq_length, $member->sequence_id);
    $sth->finish;
  } else {
    $member->sequence_id($self->db->get_SequenceAdaptor->store($member->sequence,1)); # Last parameter induces a check for redundancy

    my $sth3 = $self->prepare("UPDATE member SET sequence_id=? WHERE member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }
  return 1;
}









sub _set_member_as_canonical {
    my ($self, $member) = @_;

    assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember');

    my $sth = $self->prepare('UPDATE member SET canonical_member_id = ? WHERE member_id = ?');
    $sth->execute($member->member_id, $member->gene_member_id);
    $sth->finish;
}












### SECTION 9 ###
#
# WRAPPERS
###########













1;

