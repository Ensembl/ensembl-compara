package EnsEMBL::Web::Lazy::Hash;

use strict;
use warnings;

use Tie::Hash;

use base qw(Tie::StdHash);

use Exporter qw(import);

our @EXPORT_OK = qw(lazy_hash);

# Creates a tied hash where sets can be subs which before they are
# got are executed.

sub get { $_[0]->FETCH($_[1]); }

sub FETCH {
  my ($self,$k) = @_;

  $self->{$k} = $self->{$k}->($self) if ref($self->{$k}) eq 'CODE';
  return $self->{$k};
}

sub lazy_hash {
  my ($hashref) = @_;

  tie my %magic,'EnsEMBL::Web::Lazy::Hash';
  %magic = %$hashref;
  return \%magic;
}

1;

