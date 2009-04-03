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

#
# STORE METHODS
#
################

sub store {
  my ($self, $sequence) = @_;
  my $seqID;

  return 0 unless($sequence);

  my $dcs = $self->dbc->disconnect_when_inactive();
  $self->dbc->disconnect_when_inactive(0);

  $self->dbc->do("LOCK TABLE sequence WRITE");

  my $sth = $self->prepare("SELECT sequence_id FROM sequence WHERE sequence = ?");
  $sth->execute($sequence);
  ($seqID) = $sth->fetchrow_array();
  $sth->finish;

  unless($seqID) {
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





