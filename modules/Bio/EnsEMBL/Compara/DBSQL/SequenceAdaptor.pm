package Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub fetch_by_dbID {
  my ($self, $sequence_id) = @_;

  my $sql = "SELECT sequence.sequence FROM sequence WHERE sequence_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($sequence_id);

  my ($sequence) = $sth->fetchrow_array();
  $sth->finish();
  return $sequence;
}

sub fetch_other_sequence_by_member_id_type {
  my ($self, $member_id, $type) = @_;

  my $sql = "SELECT sequence FROM other_member_sequence WHERE member_id = ? AND seq_type = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($member_id, $type);

  my ($seq) = $sth->fetchrow_array();
  $sth->finish();
  return $seq;
}


sub fetch_sequence_exon_bounded_by_member_id {
  my ($self, $member_id) = @_;
  deprecate('fetch_sequence_exon_bounded_by_member_id() is deprecated and will be removed in e72. Use fetch_other_sequence_by_member_id_type($member_id, "exon_bounded") instead.');
  return $self->fetch_other_sequence_by_member_id_type($member_id, 'exon_bounded');
}

sub fetch_sequence_cds_by_member_id {
  my ($self, $member_id) = @_;

  deprecate('fetch_sequence_cds_by_member_id() is deprecated and will be removed in e72. Use fetch_other_sequence_by_member_id_type($member_id, "cds") instead.');
  return $self->fetch_other_sequence_by_member_id_type($member_id, 'cds');
}


#
# STORE METHODS
#
################

sub store {
  my ($self, $sequence, $check_redundancy) = @_;
  my $seqID;

  return 0 unless($sequence);

  my $dcs = $self->dbc->disconnect_when_inactive();
  $self->dbc->disconnect_when_inactive(0);

  $self->dbc->do("LOCK TABLE sequence WRITE");

  # Check redundancy is now optional -- for genomic alignments it's
  # faster to store redundant sequences than check for their
  # existance, but for the GeneTrees we keep the sequences
  # non-redundant
  if ($check_redundancy) {
    my $sth = $self->prepare("SELECT sequence_id FROM sequence WHERE sequence = ?");
    $sth->execute($sequence);
    ($seqID) = $sth->fetchrow_array();
    $sth->finish;
  }

  if(!$seqID) {
    my $length = length($sequence);

    my $sth2 = $self->prepare("INSERT INTO sequence (sequence, length) VALUES (?,?)");
    $sth2->execute($sequence, $length);
    $seqID = $sth2->{'mysql_insertid'};
    $sth2->finish;
  }

  $self->dbc->do("UNLOCK TABLES");
  $self->dbc->disconnect_when_inactive($dcs);
  return $seqID;
}

sub store_other_sequence {
    my ($self, $member, $seq, $type) = @_;
    my $sth = $self->prepare("REPLACE INTO other_member_sequence (member_id, seq_type, length, sequence) VALUES (?,?,?,?)");
    return $sth->execute($member->dbID, $type, length($seq), $seq);
}


1;


