package EnsEMBL::Web::TextSequence::Output::Web::AdornKey;

use strict;
use warnings;

use Scalar::Util qw(weaken);

sub new {
  my ($proto,$adorn,$k) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    adorn => $adorn,
    adlookid => 1,
    adlookup => {},
    adref => [""],
    key => $k
  };
  bless $self,$class;
  weaken($self->{'adorn'});
  return $self;
}

sub get_id {
  my ($self,$v) = @_;

  return undef unless $v;
  my $id = $self->{'adlookup'}{$v};
  return $id if defined $id;
  $id = $self->{'adlookid'}++;
  $self->{'adlookup'}{$v} = $id;
  return $id;
}

sub adref {
  my ($self) = @_;

  my @adref=("");
  foreach my $v (keys %{$self->{'adlookup'}}) {
    $adref[$self->{'adlookup'}{$v}] = $v;
  }
  return \@adref;
}

1;
