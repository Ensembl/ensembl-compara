package EnsEMBL::Web::QueryStore::Source::SpeciesDefs;

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

sub table_info {
  my ($self,$species,$type,$table) = @_;

  return $self->{'_sd'}->table_info_other($species,$type,$table);
}

sub config {
  my ($self,$species,$var) = @_;

  return $self->{'_sd'}->get_config($species,$var);
}

sub multi {
  my ($self,$type,$species) = @_;

  return $self->{'_sd'}->multi($type,$species);
}

sub multi_val {
  my ($self,$type,$species) = @_;

  return $self->{'_sd'}->multi_val($type,$species);
}

sub multiX {
  my ($self,$type) = @_;

  return $self->{'_sd'}->multiX($type);
}

sub list_databases {
  my ($self,$species) = @_;

  my @dbs = (keys %{$self->config($species,'databases')||{}},
             @{$self->multi_val('compara_like_databases')||[]});
  # Remove DATABASE_, convert rest to lc
  @dbs = map { s/^DATABASE_//; $_ = lc $_; } @dbs;
  return \@dbs;
}

1;
