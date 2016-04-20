package EnsEMBL::Web::QueryStore::Cache::Memcached;

use strict;
use warnings;

use Cache::Memcached;

sub new {
  my ($proto,$conf) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    cache => Cache::Memcached->new($conf)
  };
  bless $self,$class;
  return $self;
}

sub set {
  my ($self,$class,$ver,$k,$v) = @_;

  $self->{'cache'}->set($self->_key($k,$class,$ver),$v);
}

sub get {
  my ($self,$class,$ver,$k) = @_;

  return $self->{'cache'}->get($self->_key($k,$class,$ver));
}

1;
