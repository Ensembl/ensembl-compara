package EnsEMBL::Web::TextSequence::Sequence;

use strict;
use warnings;

use EnsEMBL::Web::TextSequence::Line;

# Represents all the lines of a single sequence in sequence view. On many
# views there will be multiple of these entwined, either different views
# on the same data (variants, bases, residues, etc), or different
# sequences.

sub new {
  my ($proto,$view) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    view => $view,
  };
  bless $self,$class;
  return $self;
}

sub new_line {
  my ($self) = @_;

  my $line = EnsEMBL::Web::TextSequence::Line->new($self);
  return $line;
}

sub view { return $_[0]->{'view'}; }
sub line_num { return $_[0]->{'line'}; }

sub _add {
  my ($self,$data) = @_;

  $self->{'view'}->_add_line($self->{'view'}->seq_num,$data);
}

1;
