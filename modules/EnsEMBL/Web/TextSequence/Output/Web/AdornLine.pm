package EnsEMBL::Web::TextSequence::Output::Web::AdornLine;

use strict;
use warnings;

use Scalar::Util qw(weaken);
use List::Util qw(max);
use JSON qw(encode_json);

use EnsEMBL::Web::TextSequence::Output::Web::AdornLineKey;

sub new {
  my ($proto,$adorn) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    adorn => $adorn,
    keys => {},
    line => {},
  };
  bless $self,$class;
  weaken($self->{'adorn'});
  $self->{'line'}{$_} = [] for (@{$adorn->domain});
  return $self;
}

sub key {
  my ($self,$k) = @_;

  $self->{'keys'}{$k} ||=
    EnsEMBL::Web::TextSequence::Output::Web::AdornLineKey->new($self,$k);
  return $self->{'keys'}{$k};
}

sub akey { return $_[0]->{'adorn'}->akeys($_[1]); }

sub done {
  my ($self) = @_;

  my $linelen = $self->{'adorn'}->linelen;
  foreach my $k (keys %{$self->{'line'}}) {
    push @{$self->{'line'}{$k}},undef if @{$self->{'line'}{$k}} < $linelen;
    my $ko = $self->key($k);
    $ko->addall($self->{'line'}{$k});
  }
}

sub linekeys { return [ keys %{$_[0]->{'keys'}} ]; }

sub adorn {
  my ($self,$line,$kv) = @_;

  foreach my $k (keys %{$self->{'line'}}) {
    push @{$self->{'line'}{$k}},$kv->{$k};
  }
}

1;
