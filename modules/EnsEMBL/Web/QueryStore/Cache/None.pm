package EnsEMBL::Web::QueryStore::Cache::None;

use strict;
use warnings;

sub new {
  my ($proto,$conf) = @_;

  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self,$class;
  return $self;
}

sub set {}
sub get { return undef; }

1;
