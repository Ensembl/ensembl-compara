package Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

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

sub fetch_sequence_exon_bounded_by_member_id {
  my ($self, $member_id) = @_;

  my $sql = "SELECT sequence_exon_bounded.sequence_exon_bounded FROM sequence_exon_bounded WHERE member_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($member_id);

  my ($sequence_exon_bounded) = $sth->fetchrow_array();
  $sth->finish();
  return $sequence_exon_bounded;
}

sub fetch_sequence_cds_by_member_id {
  my ($self, $member_id) = @_;

  my $sql = "SELECT sequence_cds.sequence_cds FROM sequence_cds WHERE member_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($member_id);

  my ($sequence_cds) = $sth->fetchrow_array();
  $sth->finish();
  return $sequence_cds;
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


1;





