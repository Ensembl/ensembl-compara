=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

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

=head2 fetch_by_dbIDs

  Arg [1]    : array reference $sequence_ids
  Arg [2]    : integer $batch_size [optional]
  Example    : my $sequences = $sequence_adaptor->fetch_by_dbIDs($sequence_ids);
  Description: Fetch sequences from the database in batches of $batch_size. Elements with $sequence_id of 0 (have no
               sequence stored in the database) are skipped.
               Note: this is similar to fetch_all_by_dbID_list but the returned data is in a different format
  Returntype : Hashref of sequence_id to strings
  Exceptions : none
  Caller     :
  Status     : At risk

=cut

sub fetch_by_dbIDs {
  my ($self, $sequence_ids, $batch_size) = @_;

  #Fetch in batches of batch_size
  my $sequences = [];
  $batch_size = 1000 unless (defined $batch_size);

  #Get sequences from database in batches of $batch_size. Store in a hash based on sequence_id rather than an array
  #to ensure that the returned sequences are in the same order as the list of sequence_ids.
  my $select_sql = "SELECT sequence_id, sequence FROM sequence WHERE sequence_id in ";
  my %seq_hash;
  for (my $i=0; $i < @$sequence_ids; $i+=$batch_size) {
      my @these_ids;
      for (my $j = $i; ($j < @$sequence_ids && $j < $i+$batch_size); $j++) {
          push @these_ids, $sequence_ids->[$j];
      }
      my $sql = $select_sql . "(" . join(",", @these_ids) . ")";
      my $sth = $self->prepare($sql);
      $sth->execute;
      my ($sequence_id, $sequence);
      $sth->bind_columns(\$sequence_id, \$sequence);
      while ($sth->fetch) {
          $seq_hash{$sequence_id} = $sequence;
      }
      $sth->finish;
  }
  return \%seq_hash;
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
  my $sequences;

  my $sql = "SELECT sequence_id, sequence FROM dnafrag_chunk join sequence using (sequence_id) where dnafrag_chunk_set_id=?";
  my $sth = $self->prepare($sql);
  $sth->execute($chunk_set_id);
  my ($sequence_id, $sequence);
  $sth->bind_columns(\$sequence_id, \$sequence);
  while ($sth->fetch) {
      $sequences->{$sequence_id} = $sequence if ($sequence_id);
  }
  $sth->finish();
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

  return {} unless scalar(@$seq_member_ids);
  my $ids_in_str = join(',', @$seq_member_ids);
  my $sql = "SELECT seq_member_id, sequence FROM other_member_sequence WHERE seq_member_id IN ($ids_in_str) AND seq_type = ?";
  my $res = $self->dbc->db_handle->selectall_arrayref($sql, undef, $type);
  my %seqs = (map {$_->[0] => $_->[1]} @$res);
  return \%seqs;
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

    return 0 unless($sequence);

    my $md5sum = md5_hex($sequence);

    my $sth = $self->prepare("INSERT INTO sequence (sequence, length, md5sum) VALUES (?,?,?)");
    $sth->execute($sequence, length($sequence), $md5sum);
    my $seqID = $self->dbc->db_handle->last_insert_id(undef, undef, 'sequence', 'sequence_id');
    $sth->finish;

    return $seqID;
}

sub store_no_redundancy {
    my ($self, $sequence) = @_;

    throw("store_no_redundancy() called without a sequence") unless $sequence;

    my $md5sum = md5_hex($sequence);

    # We insert no matter what
    $self->dbc->do('INSERT INTO sequence (sequence, length, md5sum) VALUES (?,?,?)', undef, $sequence, length($sequence), $md5sum);

    # And we delete the duplicates (the smallest sequence_id is the reference, i.e first come first served)
    my $matching_ids = $self->dbc->db_handle->selectcol_arrayref('SELECT sequence_id FROM sequence WHERE md5sum = ? AND sequence = ? ORDER BY sequence_id', undef, $md5sum, $sequence);
    die "The sequence disappeared !\n" unless scalar(@$matching_ids);
    my $seqID = shift @$matching_ids;

    if (scalar(@$matching_ids)) {
        my $other_ids = join(",", @$matching_ids);
        $self->dbc->do("DELETE FROM sequence WHERE sequence_id IN ($other_ids)");
    }

    return $seqID;
}

sub store_other_sequence {
    my ($self, $member, $seq, $type) = @_;
    my $sth = $self->prepare("REPLACE INTO other_member_sequence (seq_member_id, seq_type, length, sequence) VALUES (?,?,?,?)");
    return $sth->execute($member->dbID, $type, length($seq), $seq);
}


1;


