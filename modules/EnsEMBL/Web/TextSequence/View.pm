package EnsEMBL::Web::TextSequence::View;

use strict;
use warnings;

use JSON qw(encode_json);

use EnsEMBL::Web::TextSequence::Sequence;
use EnsEMBL::Web::TextSequence::Adorn;
use EnsEMBL::Web::TextSequence::Legend;

# A view is comprised of one or more interleaved sequences.

sub new {
  my ($proto,$hub,$width,$maintain) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    hub => $hub,
    seq_num => -1,
    all_line => 0,
    width => $width,
    output => [],
    adorn => EnsEMBL::Web::TextSequence::Adorn->new(),
    legend => undef,
    maintain_colour => $maintain,
  };
  bless $self,$class;
  return $self;
}

sub make_legend { # For IoC: override me if you want to
  return EnsEMBL::Web::TextSequence::Legend->new();
}

sub legend {
  my ($self) = @_;

  $self->{'legend'} ||= $self->make_legend;
  return $self->{'legend'};
}

sub new_sequence {
  my ($self) = @_;

  $self->{'seq_num'}++;
  my $seq = EnsEMBL::Web::TextSequence::Sequence->new($self);
  return $seq;
}

# Only to be called by line
sub _new_line_num { return $_[0]->{'all_line'}++; }
sub _hub { return $_[0]->{'hub'}; }
sub _maintain_colour { return $_[0]->{'maintain_colour'}; }

sub line_num { return $_[0]->{'all_line'}; }
sub seq_num { return $_[0]->{'seq_num'}; }
sub width { return $_[0]->{'width'}; }
sub output { return $_[0]->{'output'}; }
sub adorn { return $_[0]->{'adorn'}; }

# Only to be called from sequence
sub _add_line {
  my ($self,$seq,$data) = @_;

  push @{$self->{'output'}[$seq]},$data;
}

1;
