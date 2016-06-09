package EnsEMBL::Web::TextSequence::View;

use strict;
use warnings;

use EnsEMBL::Web::TextSequence::Sequence;

# A view is comprised of one or more interleaved sequences.

sub new {
  my ($proto,$width) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    seq_num => -1,
    all_line => 0,
    width => $width,
    output => [],
    addata => {},
    adlookup => {},
    adlookid => {},
  };
  bless $self,$class;
  return $self;
}

sub new_sequence {
  my ($self) = @_;

  $self->{'seq_num'}++;
  my $seq = EnsEMBL::Web::TextSequence::Sequence->new($self);
  return $seq;
}

# Only to be called by line
sub _new_line_num { return $_[0]->{'all_line'}++; }

sub line_num { return $_[0]->{'all_line'}; }
sub seq_num { return $_[0]->{'seq_num'}; }
sub addata { return $_[0]->{'addata'}; }
sub adlookup { return $_[0]->{'adlookup'}; }
sub width { return $_[0]->{'width'}; }
sub output { return $_[0]->{'output'}; }

# Only to be called from Line
sub _adorn {
  my ($self,$line,$char,$k,$v) = @_;

  $self->{'addata'}{$line}[$char]||={};
  return unless $v;
  $self->{'adlookup'}{$k} ||= {};
  $self->{'adlookid'}{$k} ||= 1;
  my $id = $self->{'adlookup'}{$k}{$v};
  unless(defined $id) {
    $id = $self->{'adlookid'}{$k}++;
    $self->{'adlookup'}{$k}{$v} = $id;
  }
  $self->{'addata'}{$line}[$char]{$k} = $id;
}

# Only to be called from sequence
sub _add_line {
  my ($self,$seq,$data) = @_;

  push @{$self->{'output'}[$seq]},$data;
}

1;
