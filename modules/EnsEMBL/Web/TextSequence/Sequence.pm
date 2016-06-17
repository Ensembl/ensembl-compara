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
    exon => "",
    pre => "",
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

# only for use in Line
sub _exon {
  my ($self,$val) = @_;

  $self->{'exon'} = $val if @_>1;
  return $self->{'exon'};
}

sub _add {
  my ($self,$data) = @_;

  $self->{'view'}->_add_line($self->{'view'}->seq_num,$data);
}

sub pre {
  my ($self,$val) = @_;

  $self->{'pre'} .= $val if @_>1;
  return $self->{'pre'};
}

1;
