package EnsEMBL::Web::QueryStore::Source::Adaptors;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::DBConnection;

sub new {
  my ($proto,$sd) = @_;

  my $class = ref($proto) || $proto;
  my $self = { _sd => $sd };
  bless $self,$class;
  return $self;
}

sub _database {
  my ($self,$species,$db) = @_;

  $db ||= 'core';
  if($db =~ /compara/) {
    $species = 'multi';
  }
  my $dbc = EnsEMBL::Web::DBSQL::DBConnection->new($species,$self->{'_sd'});
  return $dbc->get_DBAdaptor($db,$species);
}

sub _get_adaptor {
  my ($self,$method,$db,$species) = @_;

  return $self->_database($species,$db)->$method();
}

sub slice_adaptor {
  my ($self,$species) = @_;

  return $self->_get_adaptor('get_SliceAdaptor',undef,$species);
}

sub slice_by_name {
  my ($self,$species,$name) = @_;

  return $self->slice_adaptor($species)->fetch_by_name($name);
}

sub variation_db_adaptor {
  my ($self,$var_db,$species) = @_;

  return $self->_database($species,$var_db);
}

sub compara_db_adaptor {
  my ($self) = @_;

  return $self->_database(undef,'compara');
}

1;
