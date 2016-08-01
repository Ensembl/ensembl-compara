package EnsEMBL::Web::TextSequence::Annotation;

use strict;
use warnings;

sub new {
  my ($proto,$p) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    phases => $p,
  };
  bless $self,$class;
  return $self;
}

sub phases { $_[0]->{'phases'} = $_[1] if @_>1; return $_[0]->{'phases'}; }

1;
