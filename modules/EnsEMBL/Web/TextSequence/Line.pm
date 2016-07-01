package EnsEMBL::Web::TextSequence::Line;

use strict;
use warnings;

# Represents a single line of text sequence

sub new {
  my ($proto,$seq) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    pre => "",
    post => "",
    count => 0,
    line_num => $seq->view->_new_line_num,
    hub => $seq->view->_hub,
    seq => $seq,
    markup => [{}],
  };
  bless $self,$class;
  return $self;
}

sub seq { return $_[0]->{'seq'}; }
sub line_num { return $_[0]->{'line_num'}; }
sub pre { return $_[0]->seq->{'pre'}.$_[0]->{'pre'}; }
sub post { return $_[0]->{'post'}; }
sub add_pre { $_[0]->{'pre'} .= ($_[1]||''); }
sub add_post { $_[0]->{'post'} .= ($_[1]||''); }

sub post { return $_[0]->{'post'}; }
sub count { return $_[0]->{'count'}; }

sub full { $_[0]->{'count'} >= $_[0]->{'seq'}->view->width }

sub markup {
  my ($self,$k,$v) = @_;

  $self->{'markup'}->[-1]{$k} = $v;
}

sub advance {
  my ($self) = @_;

  push @{$self->{'markup'}},{};
  $self->{'count'}++;
}

sub add {
  my ($self,$config) = @_;

  pop @{$self->{'markup'}};
  foreach my $m (@{$self->{'markup'}}) {
    $self->{'seq'}->fixup_markup($m,$config);
  }
  $self->{'seq'}->view->output->add_line($self,$self->{'markup'},$config);
}

1;
