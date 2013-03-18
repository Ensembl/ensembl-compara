=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor

=head1 DESCRIPTION

Adaptor to retrieve SeqMember objects.
Most of the methods are shared with the GeneMemberAdaptor.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning stack_trace_dump);
use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor);



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

  Arg [1]    : int gene_member_id of a gene member
  Example    : @pepMembers = @{$SeqMemberAdaptor->fetch_all_by_gene_member_id($gene_member_id)};
  Description: given a gene_member_id of a gene member, fetches all sequence members for this gene
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

    my $join = [[['gene_member', 'mg'], 'mg.canonical_member_id = m.seq_member_id']];

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND mg.genome_db_id = ?', $join);
}




=head2 fetch_canonical_for_gene_member_id

  Arg [1]    : int gene_member_id of a gene member
  Example    : $members = $memberAdaptor->fetch_canonical_for_gene_member_id($gene_member_id);
  Description: given a gene_member_id of a gene member,
               fetches the canonical peptide / transcript member for this gene
  Returntype : Bio::EnsEMBL::Compara::SeqMember object
  Exceptions :
  Caller     : general

=cut

sub fetch_canonical_for_gene_member_id {
    my ($self, $gene_member_id) = @_;

    throw() unless (defined $gene_member_id);

    my $constraint = 'mg.gene_member_id = ?';
    my $join = [[['gene_member', 'mg'], 'm.seq_member_id = mg.canonical_member_id']];

    $self->bind_param_generic_fetch($gene_member_id, SQL_INTEGER);
    return $self->generic_fetch_one($constraint, $join);
}




#
# INTERNAL METHODS
#
###################


sub _tables {
  return (['seq_member', 'm']);
}

sub _columns {
  return ('m.seq_member_id',
          'm.source_name',
          'm.stable_id',
          'm.version',
          'm.taxon_id',
          'm.genome_db_id',
          'm.description',
          'm.chr_name',
          'm.chr_start',
          'm.chr_end',
          'm.chr_strand',
          'm.sequence_id',
          'm.gene_member_id',
          'm.display_label'
          );
}

sub create_instance_from_rowhash {
	my ($self, $rowhash) = @_;
	
	return Bio::EnsEMBL::Compara::SeqMember->new_fast({
		adaptor         => $self,
		dbID            => $rowhash->{seq_member_id},
		_stable_id      => $rowhash->{stable_id},
		_version        => $rowhash->{version},
		_taxon_id       => $rowhash->{taxon_id},
		_genome_db_id   => $rowhash->{genome_db_id},
		_description    => $rowhash->{description},
		_chr_name       => $rowhash->{chr_name},
		dnafrag_start   => $rowhash->{chr_start} || 0,
		dnafrag_end     => $rowhash->{chr_end} || 0,
		dnafrag_strand  => $rowhash->{chr_strand} || 0,
		_sequence_id    => $rowhash->{sequence_id} || 0,
		_source_name    => $rowhash->{source_name},
		_display_label  => $rowhash->{display_label},
		_gene_member_id => $rowhash->{gene_member_id},
	});
}

sub init_instance_from_rowhash {
  my $self = shift;
  my $member = shift;
  my $rowhash = shift;

  $member->seq_member_id($rowhash->{'seq_member_id'});
  $member->stable_id($rowhash->{'stable_id'});
  $member->version($rowhash->{'version'});
  $member->taxon_id($rowhash->{'taxon_id'});
  $member->genome_db_id($rowhash->{'genome_db_id'});
  $member->description($rowhash->{'description'});
  $member->chr_name( $rowhash->{'chr_name'} );
  $member->dnafrag_start($rowhash->{'chr_start'} || 0 );
  $member->dnafrag_end( $rowhash->{'chr_end'} || 0 );
  $member->dnafrag_strand($rowhash->{'chr_strand'} || 0 );
  $member->sequence_id($rowhash->{'sequence_id'});
  $member->gene_member_id($rowhash->{'gene_member_id'});
  $member->source_name($rowhash->{'source_name'});
  $member->display_label($rowhash->{'display_label'});
  $member->adaptor($self) if ref $self;

  return $member;
}




#
# STORE METHODS
#
################


sub store {
    my ($self, $member) = @_;
   
    $self->_warning_member_adaptor();
    assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember');


  my $sth = $self->prepare("INSERT ignore INTO seq_member (stable_id,version, source_name,
                              gene_member_id,
                              taxon_id, genome_db_id, description,
                              chr_name, chr_start, chr_end, chr_strand,display_label)
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");

  my $insertCount = $sth->execute($member->stable_id,
                  $member->version,
                  $member->source_name,
                  $member->gene_member_id,
                  $member->taxon_id,
                  $member->genome_db_id,
                  $member->description,
                  $member->chr_name,
                  $member->chr_start,
                  $member->chr_end,
                  $member->chr_strand,
                  $member->display_label);
  if($insertCount>0) {
    #sucessful insert
    $member->dbID( $sth->{'mysql_insertid'} );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(source_name,stable_id) prevented insert since member was already inserted
    #so get seq_member_id with select
    my $sth2 = $self->prepare("SELECT seq_member_id, sequence_id FROM member WHERE source_name=? and stable_id=?");
    $sth2->execute($member->source_name, $member->stable_id);
    my($id, $sequence_id) = $sth2->fetchrow_array();
    warn("MemberAdaptor: insert failed, but seq_member_id select failed too") unless($id);
    $member->dbID($id);
    $member->sequence_id($sequence_id) if ($sequence_id);
    $sth2->finish;
  }

  $member->adaptor($self);

  # insert in sequence table to generate new
  # sequence_id to insert into member table;
  if(defined($member->sequence) and $member->sequence_id == 0) {
    $member->sequence_id($self->db->get_SequenceAdaptor->store($member->sequence,1)); # Last parameter induces a check for redundancy

    my $sth3 = $self->prepare("UPDATE seq_member SET sequence_id=? WHERE seq_member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }

  return $member->dbID;
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

    my $sth3 = $self->prepare("UPDATE member SET sequence_id=? WHERE seq_member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }
  return 1;
}



sub _set_member_as_canonical {
    my ($self, $member) = @_;

    assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember');

    my $sth = $self->prepare('UPDATE gene_member SET canonical_member_id = ? WHERE gene_member_id = ?');
    $sth->execute($member->seq_member_id, $member->gene_member_id);
    $sth->finish;
}



1;

