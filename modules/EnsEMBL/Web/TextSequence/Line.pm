package EnsEMBL::Web::TextSequence::Line;

use strict;
use warnings;

# Represents a single line of text sequence

sub new {
  my ($proto,$seq) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    letters => "",
    pre => "",
    post => "",
    count => 0,
    line_num => $seq->view->_new_line_num,
    seq => $seq,
  };
  bless $self,$class;
  return $self;
}

sub add_letter { $_[0]->{'letters'} .= ($_[1]||' '); $_[0]->{'count'}++; }
sub add_pre { $_[0]->{'pre'} .= ($_[1]||''); }
sub add_post { $_[0]->{'post'} .= ($_[1]||''); }

sub post { return $_[0]->{'post'}; }
sub count { return $_[0]->{'count'}; }
sub output { return $_[0]->{'output'}; }

sub full { $_[0]->{'count'} >= $_[0]->{'seq'}->view->width }

sub adorn {
  my ($self,$k,$v) = @_;

  $self->{'seq'}->view->_adorn($self->{'line_num'},$self->{'count'},$k,$v);
}

sub add {
  my ($self) = @_;

  $self->{'seq'}->_add({
    line => $self->{'letters'},
    length => $self->{'count'},
    pre => $self->{'pre'},
    post => $self->{'post'},
    adid => $self->{'line_num'}
  });
}

1;
