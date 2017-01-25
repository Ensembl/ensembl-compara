package EnsEMBL::Web::Utils::SecretForm;

# "Secret forms" allows ensembl to tunnel fields through the form
# submission process in an unforgable way. Fields are actually stored
# in sessions, along with by a strong random number. This number
# is then included in the form proper. When the form is submitted, the
# details are retrieved from the cookie (and optionally deleted, which
# will prevent replay attacks, but break "back-button & resubmit").
#
# Each secret form has a persistence key such that only one set of data
# is present within the cookie for each key. This manages its size but
# minimally interferes with back-button behaviour, etc, compared to
# other solutions.

use strict;
use warnings;

use EnsEMBL::Web::Utils::Crypto qw(random_key);

# XXX delete
sub new {
  my ($proto,$hub,$pkey) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    hub => $hub,
    pkey => $pkey,
    fields => {}
  };
  bless $self,$class;
  return $self;
}

sub load {
  my ($self,$key) = @_;

  my $c = $self->{'hub'}->session->get_record_data({
    type => 'secretform',
    code => $self->{'pkey'}
  });
  unless($c->{'lock'} and $c->{'lock'} eq $key) {
    warn "rejected bad key\n";
    return;
  }
  $self->{'fields'}{$_} = $c->{'fields'}{$_} for keys %{$c->{'fields'}};
}

sub set { $_[0]->{'fields'}{$_[1]} = $_[2]; }

sub get { return $_[0]->{'fields'}{$_[1]}; }

sub save {
  my ($self) = @_;

  my $k = random_key(32);
  my $c = $self->{'hub'}->session->set_record_data({
    type => 'secretform',
    code => $self->{'pkey'},
    lock => $k,
    fields => {%{$self->{'fields'}}}
  });
  return $k;
}

1;
