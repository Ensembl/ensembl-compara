package EnsEMBL::Web::QueryStore::TestSource;

use strict;
use warnings;

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self,$class;
  return $self;
}

sub incr {
  my ($self,$x) = @_;

  return $x+1;
}

1;
