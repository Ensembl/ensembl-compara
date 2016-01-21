package EnsEMBL::Web::QueryStore::Source::Adaptors;

use strict;
use warnings;

sub new {
  my ($proto,$hub) = @_;

  my $class = ref($proto) || $proto;
  my $self = { _hub => $hub };
  bless $self,$class;
  return $self;
}

sub _get_adaptor {
  my ($self,$method,$db,$species) = @_;

  return $self->{'_hub'}->get_adaptor($method,$db,$species);
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

  return  $self->{'_hub'}->database($var_db,$species);
}

1;
