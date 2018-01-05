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

package Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);
use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw deprecate);

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID

  Arg [1]    : integer $sequence_id
  Example    : my $sequence = $sequence_adaptor->fetch_by_dbID($sequence_id);
  Description: Fetch a single sequence.
  Returntype : string
  Exceptions : none
  Caller     :
  Status     : Stable

=cut

sub fetch_by_dbID {
  my ($self, $sequence_id) = @_;

  my $sql = "SELECT sequence.sequence FROM sequence WHERE sequence_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($sequence_id);

  my ($sequence) = $sth->fetchrow_array();
  $sth->finish();
  return $sequence;
}

=head2 fetch_all_by_dbID_list

  Arg [1]    : array reference $sequence_ids
  Example    : my $sequences = $sequence_adaptor->fetch_all_by_dbID_list($sequence_ids);
  Description: Fetch sequences from the database in batches.
               Note: the returned data are in a different format than traditional fetch_all_by_dbID_list() methods
  Returntype : Hashref of sequence_id to strings
  Exceptions : none
  Caller     :

=cut

sub fetch_all_by_dbID_list {
  my ($self, $sequence_ids) = @_;

  my $select_sql = "SELECT sequence_id, sequence FROM sequence WHERE ";
  return $self->_fetch_by_list($sequence_ids, $select_sql, 'sequence_id', SQL_INTEGER);
}

sub _fetch_by_list {
  my ($self, $id_list, $select_sql, $column_name, $column_sql_type, @args) = @_;

  my %seq_hash;
  $self->split_and_callback($id_list, $column_name, $column_sql_type, sub {
      my $sql = $select_sql . (shift);
      $self->generic_fetch_hash($sql, \%seq_hash, @args);
  } );
  return \%seq_hash;
}


sub generic_fetch_hash {
      my ($self, $sql, $seq_hash, @args) = @_;
      my $sth = $self->prepare($sql);
      $sth->execute(@args);
      my ($sequence_id, $sequence);
      $sth->bind_columns(\$sequence_id, \$sequence);
      while ($sth->fetch) {
          $seq_hash->{$sequence_id} = $sequence;
      }
      $sth->finish;
}

=head2 fetch_all_by_chunk_set_id

  Arg [1]    : integer $chunk_set_id
  Example    : my $sequences = $sequence_adaptor->fetch_all_by_chunk_set_id($chunk_set_id);
  Description: Fetch sequences from the database by chunk_set. Does not retrieve sequences with a sequence_id of 0.
  Returntype : hash ref of strings using sequence_id as the key
  Exceptions : none
  Caller     :
  Status     : At risk

=cut

sub fetch_all_by_chunk_set_id {
  my ($self, $chunk_set_id) = @_;
  my $sequences = {};

  my $sql = "SELECT sequence_id, sequence FROM dnafrag_chunk join sequence using (sequence_id) where dnafrag_chunk_set_id=?";
  $self->generic_fetch_hash($sql, $sequences, $chunk_set_id);
  return $sequences;
}

sub fetch_other_sequence_by_member_id_type {
  my ($self, $seq_member_id, $type) = @_;

  my $sql = "SELECT sequence FROM other_member_sequence WHERE seq_member_id = ? AND seq_type = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($seq_member_id, $type);

  my ($seq) = $sth->fetchrow_array();
  $sth->finish();
  return $seq;
}

sub fetch_other_sequences_by_member_ids_type {
  my ($self, $seq_member_ids, $type) = @_;

  my $select_sql = "SELECT seq_member_id, sequence FROM other_member_sequence WHERE seq_type = ? AND ";
  return $self->_fetch_by_list($seq_member_ids, $select_sql, 'seq_member_id', SQL_INTEGER, $type);
}

#
# STORE METHODS
#
# Check redundancy is now optional -- for genomic alignments it's
# faster to store redundant sequences than check for their
# existance, but for the GeneTrees we keep the sequences
# non-redundant
#
################

sub store {
    my ($self, $sequence) = @_;

    throw("SequenceAdaptor::store() called without a sequence") unless $sequence;

    my $md5sum = md5_hex($sequence);

    my $sth = $self->prepare("INSERT INTO sequence (sequence, length, md5sum) VALUES (?,?,?)");
    $sth->execute($sequence, length($sequence), $md5sum);
    my $seqID = $self->dbc->db_handle->last_insert_id(undef, undef, 'sequence', 'sequence_id');
    $sth->finish;

    return $seqID;
}

sub store_no_redundancy {
    my ($self, $sequence) = @_;

    throw("SequenceAdaptor::store_no_redundancy() called without a sequence") unless $sequence;

    my $md5sum = md5_hex($sequence);

    # We insert no matter what
    $self->dbc->do('INSERT INTO sequence (sequence, length, md5sum) VALUES (?,?,?)', undef, $sequence, length($sequence), $md5sum);

    # We find the repetitions
    my $matching_ids = $self->dbc->db_handle->selectcol_arrayref('SELECT sequence_id FROM sequence WHERE md5sum = ? AND sequence = ?', undef, $md5sum, $sequence);

    die "The sequence disappeared !\n" unless scalar(@$matching_ids);
    return $matching_ids->[0] if scalar(@$matching_ids)==1;

    # And we delete the duplicates (the smallest sequence_id is the reference, i.e first come first served)
    my @ordered_ids = sort {$a <=> $b} @$matching_ids;
    my $seqID = shift @ordered_ids;
    my $ids_in = $self->generate_in_constraint(\@ordered_ids, 'sequence_id', SQL_INTEGER, 1);
    $self->dbc->do("DELETE FROM sequence WHERE $ids_in");
    return $seqID;
}

sub store_other_sequence {
    my ($self, $member, $seq, $type) = @_;
    my $sth = $self->prepare("REPLACE INTO other_member_sequence (seq_member_id, seq_type, length, sequence) VALUES (?,?,?,?)");
    return $sth->execute($member->dbID, $type, length($seq), $seq);
}


1;


