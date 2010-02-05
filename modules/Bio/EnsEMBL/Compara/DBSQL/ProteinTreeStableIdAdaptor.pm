package Bio::EnsEMBL::Compara::DBSQL::ProteinTreeStableIdAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub fetch_by_node_id {
  my ($self, $node_id) = @_;
  return $self->fetch_stable_id_by_node_id($node_id);
}

sub fetch_stable_id_by_node_id {
  my ($self, $node_id) = @_;

  my $sql = "SELECT stable_id FROM protein_tree_stable_id WHERE node_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($node_id);

  my ($stable_id) = $sth->fetchrow_array();
  $sth->finish();
  return $stable_id;
}

sub fetch_node_id_by_stable_id {
  my ($self, $stable_id) = @_;

  my $sql = "SELECT node_id FROM protein_tree_stable_id WHERE stable_id=\"$stable_id\"";
  my $sth = $self->prepare($sql);
  $sth->execute();

  my ($node_id) = $sth->fetchrow_array();
  $sth->finish();

  return $node_id;
}

1;





