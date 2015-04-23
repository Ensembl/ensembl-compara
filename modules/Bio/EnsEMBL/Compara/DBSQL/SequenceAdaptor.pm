=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  Returntype : array ref of strings. These are returned in the same order as the $sequence_ids array.
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
  #Order sequences according to sequence_ids array
  foreach my $seq_id (@$sequence_ids) {
      push @$sequences, $seq_hash{$seq_id} if ($seq_id); #ignore sequence_id of 0
  }

  #print "num seqs " . @$sequences . "\n";
  return $sequences;
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

    my $sth = $self->prepare("INSERT INTO sequence (sequence, length) VALUES (?,?)");
    $sth->execute($sequence, length($sequence));
    my $seqID = $self->dbc->db_handle->last_insert_id(undef, undef, 'sequence', 'sequence_id');
    $sth->finish;

    return $seqID;
}

sub store_no_redundancy {
  my ($self, $sequence) = @_;
  my $seqID;

  return 0 unless($sequence);

  # NOTE: disconnect_when_inactive() OK: we need to make sure we don't
  # disconnect just after acquiring the lock
  # Use $self->dbc->prevent_disconnect(sub {...} ) ?
  my $dcs = $self->dbc->disconnect_when_inactive();
  $self->dbc->disconnect_when_inactive(0);

  $self->dbc->do("LOCK TABLE sequence WRITE");

    my $sth = $self->prepare("SELECT sequence_id FROM sequence WHERE sequence = ?");
    $sth->execute($sequence);
    ($seqID) = $sth->fetchrow_array();
    $sth->finish;

  if(!$seqID) {
    $seqID = $self->store($sequence);
  }

  $self->dbc->do("UNLOCK TABLES");
  $self->dbc->disconnect_when_inactive($dcs);
  return $seqID;
}

sub store_other_sequence {
    my ($self, $member, $seq, $type) = @_;
    my $sth = $self->prepare("REPLACE INTO other_member_sequence (seq_member_id, seq_type, length, sequence) VALUES (?,?,?,?)");
    return $sth->execute($member->dbID, $type, length($seq), $seq);
}


1;


