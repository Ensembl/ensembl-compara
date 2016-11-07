package EnsEMBL::Web::TextSequence::RopeOutput;

use strict;
use warnings;

use Scalar::Util qw(weaken);

sub new {
  my ($proto,$rope) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    rope => $rope,
    lines => []
  };
  weaken($self->{'rope'});
  bless $self,$class;
  return $self;
}

sub add_line {
  my ($self,$line) = @_;

  push @{$self->{'lines'}},$line;
}

sub lines { return $_[0]->{'lines'}; }

1;
