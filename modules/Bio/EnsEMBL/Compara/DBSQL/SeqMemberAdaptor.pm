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

use Bio::EnsEMBL::Compara::SeqMember;

use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);

use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);

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




=head2 fetch_all_by_GeneMember

  Arg [1]    : Bio::EnsEMBL::Compara::GeneMember
  Example    : @pepMembers = @{$SeqMemberAdaptor->fetch_all_by_GeneMember($gene_member)};
  Description: fetches all sequence members for this gene
  Returntype : array ref of Bio::EnsEMBL::Compara::SeqMember objects
  Exceptions : $gene_member not defined
  Caller     : general

=cut

sub fetch_all_by_GeneMember {
    my ($self, $gene_member) = @_;

    assert_ref_or_dbID($gene_member, 'Bio::EnsEMBL::Compara::GeneMember', 'gene_member');

    $self->bind_param_generic_fetch(ref($gene_member) ? $gene_member->dbID : $gene_member, SQL_INTEGER);
    return $self->generic_fetch('m.gene_member_id = ?');
}


=head2 fetch_all_canonical_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB or its dbID
  Arg [2]    : String: $source_name
  Example    : @canMembers = @{$SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($human_gdb)};
  Description: fetches all the canonical members of a given species (can be refined by $source_name)
  Returntype : array ref of Bio::EnsEMBL::Compara::SeqMember objects
  Exceptions : arguments not defined
  Caller     : general

=cut

sub fetch_all_canonical_by_GenomeDB {
    my ($self, $genome_db, $source_name) = @_;

    assert_ref_or_dbID($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');

    my $join = [[['gene_member', 'mg'], 'mg.canonical_member_id = m.seq_member_id']];
    my $constraint = 'mg.genome_db_id = ?';
    $self->bind_param_generic_fetch(ref($genome_db) ? $genome_db->dbID : $genome_db, SQL_INTEGER);

    if ($source_name) {
        $constraint .= ' AND m.source_name = ?';
        $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    }

    return $self->generic_fetch($constraint, $join);
}


sub _fetch_all_representative_for_blast_by_genome_db_id {
    my ($self, $genome_db_id, $start_member_id, $end_member_id) = @_;

    my $join = [[['seq_member_projection', 'left_projection'], 'left_projection.target_seq_member_id IS NULL'] ];
    my $constraint = 'm.genome_db_id = ?';
    my $final_clause = 'GROUP BY seq_member_id';
    $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);

    if ($start_member_id and $end_member_id) {
        $constraint .= ' AND m.seq_member_id BETWEEN ? AND ?';
        $self->bind_param_generic_fetch($start_member_id, SQL_INTEGER);
        $self->bind_param_generic_fetch($end_member_id, SQL_INTEGER);
    }

    return $self->generic_fetch($constraint, $join, $final_clause);
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

    throw('No gene_member_id given') unless (defined $gene_member_id);

    my $constraint = 'mg.gene_member_id = ?';
    my $join = [[['gene_member', 'mg'], 'm.seq_member_id = mg.canonical_member_id']];

    $self->bind_param_generic_fetch($gene_member_id, SQL_INTEGER);
    return $self->generic_fetch_one($constraint, $join);
}


=head2 fetch_by_Translation

  Arg[1]      : Bio::EnsEMBL::Translation
  Arg[2]      : (opt) boolean: $verbose
  Example     : my $seq_member = $seqmember_adaptor->fetch_by_Translation($translation);
  Description : Returns the SeqMember equivalent of the given Translation object
                If $verbose is switched on and the translation is not in Compara, prints a warning.
  Returntype  : Bio::EnsEMBL::Compara::SeqMember
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_by_Translation {
    my ($self, $translation, $verbose) = @_;

    assert_ref($translation, 'Bio::EnsEMBL::Translation', 'translation');
    my $seq_member = $self->fetch_by_stable_id($translation->stable_id);
    warn $translation->stable_id." does not exist in the Compara database\n" if $verbose and not $seq_member;
    return $seq_member;
}


=head2 fetch_by_Transcript

  Arg[1]      : Bio::EnsEMBL::Transcript
  Arg[2]      : (opt) boolean: $verbose
  Example     : my $seq_member = $seqmember_adaptor->fetch_by_Transcript($transcript);
  Description : Returns the SeqMember equivalent of the given Transcript object
                If $verbose is switched on and the transcript is not in Compara, prints a warning.
  Returntype  : Bio::EnsEMBL::Compara::SeqMember
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_by_Transcript {
    my ($self, $transcript, $verbose) = @_;

    assert_ref($transcript, 'Bio::EnsEMBL::Transcript', 'transcript');
    my $stable_id_for_compara = $transcript->translation ? $transcript->translation->stable_id : $transcript->stable_id;
    my $seq_member = $self->fetch_by_stable_id($stable_id_for_compara);
    warn $stable_id_for_compara." does not exist in the Compara database\n" if $verbose and not $seq_member;
    return $seq_member;
}


=head2 fetch_exon_boundaries_by_SeqMember

  Example     : $seqmember_adaptor->fetch_exon_boundaries_by_SeqMember($seq);
  Description : Returns the coordinates of all the exons of all the transcripts of this Seq
  Returntype  : Arrayref of [start,end,sequence_length,left_over] coordinates
  Exceptions  : none

=cut

sub fetch_exon_boundaries_by_SeqMember {
    my ($self, $seq_member) = @_;

    assert_ref_or_dbID($seq_member, 'Bio::EnsEMBL::Compara::SeqMember', 'seq_member');
    my $seq_member_id = ref($seq_member) ? $seq_member->dbID : $seq_member;
    return $self->dbc->db_handle->selectall_arrayref('SELECT dnafrag_start, dnafrag_end, sequence_length, left_over FROM exon_boundaries WHERE seq_member_id = ?', undef, $seq_member_id);
}


=head2 _store_exon_boundaries_for_SeqMember

  Arg[1]      : Bio::EnsEMBL::Compara::SeqMember $seq_member
  Arg[2]      : Arrayref of [$start,$end] coordinates
  Example     : $seqmember_adaptor->_store_exon_boundaries_for_SeqMember($seq_member, $exons);
  Description : Store the given exon coordinates for this SeqMember
  Returntype  : none
  Exceptions  : none

=cut

sub _store_exon_boundaries_for_SeqMember {
    my ($self, $seq_member, $exons) = @_;

    assert_ref($seq_member, 'Bio::EnsEMBL::Compara::SeqMember', 'seq_member');
    my $seq_member_id = $seq_member->dbID;
    my $gene_member_id = $seq_member->gene_member_id;

    # Delete data from a previous (aborted ?) run
    $self->dbc->do('DELETE FROM exon_boundaries WHERE seq_member_id = ?', undef, $seq_member_id);
    # Insert the coordinates
    my $sth = $self->prepare('INSERT INTO exon_boundaries (gene_member_id, seq_member_id, dnafrag_start, dnafrag_end, sequence_length, left_over) VALUES (?,?,?,?,?,?)');
    $sth->execute($gene_member_id, $seq_member_id, @$_) for @$exons;
    $sth->finish;
}


#
# INTERNAL METHODS
#
###################

sub _left_join {
    return (
        ['seq_member_projection left_projection', 'left_projection.target_seq_member_id = m.seq_member_id'],
        # ['seq_member_projection left_source_proj', 'left_source_proj.source_seq_member_id = m.seq_member_id'],
    );
}

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
          'm.dnafrag_id',
          'm.dnafrag_start',
          'm.dnafrag_end',
          'm.dnafrag_strand',
          'm.sequence_id',
          'm.gene_member_id',
          'm.has_transcript_edits',
          'm.has_translation_edits',
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
		dnafrag_id      => $rowhash->{dnafrag_id},
		dnafrag_start   => $rowhash->{dnafrag_start},
		dnafrag_end     => $rowhash->{dnafrag_end},
		dnafrag_strand  => $rowhash->{dnafrag_strand},
		_sequence_id    => $rowhash->{sequence_id} || 0,
		_source_name    => $rowhash->{source_name},
		_display_label  => $rowhash->{display_label},
		_gene_member_id => $rowhash->{gene_member_id},
                _has_transcript_edits   => $rowhash->{has_transcript_edits},
                _has_translation_edits  => $rowhash->{has_translation_edits},
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
  $member->dnafrag_id($rowhash->{'dnafrag_id'});
  $member->dnafrag_start($rowhash->{'dnafrag_start'});
  $member->dnafrag_end($rowhash->{'dnafrag_end'});
  $member->dnafrag_strand($rowhash->{'dnafrag_strand'});
  $member->sequence_id($rowhash->{'sequence_id'});
  $member->gene_member_id($rowhash->{'gene_member_id'});
  $member->source_name($rowhash->{'source_name'});
  $member->display_label($rowhash->{'display_label'});
  $member->has_transcript_edits($rowhash->{'has_transcript_edits'});
  $member->has_translation_edits($rowhash->{'has_translation_edits'});
  $member->adaptor($self) if ref $self;

  return $member;
}




#
# STORE METHODS
#
################


sub store {
    my ($self, $member) = @_;
   
    assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember', 'member');


  my $sth = $self->prepare("INSERT ignore INTO seq_member (stable_id,version, source_name,
                              gene_member_id, has_transcript_edits, has_translation_edits,
                              taxon_id, genome_db_id, description,
                              dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, display_label)
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

  my $insertCount = $sth->execute($member->stable_id,
                  $member->version,
                  $member->source_name,
                  $member->gene_member_id,
                  $member->has_transcript_edits,
                  $member->has_translation_edits,
                  $member->taxon_id,
                  $member->genome_db_id,
                  $member->description,
                  $member->dnafrag_id,
                  $member->dnafrag_start,
                  $member->dnafrag_end,
                  $member->dnafrag_strand,
                  $member->display_label);
  if($insertCount>0) {
    #sucessful insert
    $member->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'seq_member', 'seq_member_id') );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(stable_id) prevented insert since seq_member was already inserted
    #so get seq_member_id with select
    my $sth2 = $self->prepare("SELECT seq_member_id, sequence_id, genome_db_id FROM seq_member WHERE stable_id=?");
    $sth2->execute($member->stable_id);
    my($id, $sequence_id, $genome_db_id) = $sth2->fetchrow_array();
    warn("SeqMemberAdaptor: insert failed, but seq_member_id select failed too") unless($id);
    throw(sprintf('%s already exists and belongs to a different species (%s) ! Stable IDs must be unique across the whole set of species', $member->stable_id, $self->db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id)->name )) if $genome_db_id and $member->genome_db_id and $genome_db_id != $member->genome_db_id;
    $member->dbID($id);
    $member->sequence_id($sequence_id) if ($sequence_id) and $member->isa('Bio::EnsEMBL::Compara::SeqMember');
    $sth2->finish;
  }

  $member->adaptor($self);

  # insert in sequence table to generate new
  # sequence_id to insert into member table;
  if(defined($member->sequence) and $member->sequence_id == 0) {
    $member->sequence_id($self->db->get_SequenceAdaptor->store_no_redundancy($member->sequence));

    my $sth3 = $self->prepare("UPDATE seq_member SET sequence_id=? WHERE seq_member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }

  return $member->dbID;
}


sub _set_member_as_canonical {
    my ($self, $member) = @_;

    assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember', 'member');

    my $sth = $self->prepare('UPDATE gene_member SET canonical_member_id = ? WHERE gene_member_id = ?');
    $sth->execute($member->seq_member_id, $member->gene_member_id);
    $sth->finish;
}



1;

