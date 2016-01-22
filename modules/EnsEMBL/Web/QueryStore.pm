package EnsEMBL::Web::QueryStore;

use strict;
use warnings;

use JSON;
use Digest::MD5 qw(md5_base64);

use EnsEMBL::Web::Query;

my $DEBUG = 1;
my $DISABLE = 1;

sub new {
  my ($proto,$sources,$cache,$cohort) = @_;

  my $class = ref($proto) || $proto;
  my $self = { sources => $sources, cache => $cache };
  bless $self,$class;
  return $self;
}

sub get {
  my ($self,$query) = @_;

  return EnsEMBL::Web::Query->_new($self,"EnsEMBL::Web::Query::$query");
}

sub _source { return $_[0]->{'sources'}{$_[1]}; }

sub _key {
  my ($self,$args) = @_;

  my $json = JSON->new->canonical(1)->encode($args);
  warn "$json\n" if $DEBUG > 1;
  my $key = md5_base64($json);
  warn "$key\n" if $DEBUG > 1;
  return $key;
}

sub _try_get_cache {
  my ($self,$class,$sub,$args) = @_;

  return undef if $DISABLE;
  my $out = $self->{'cache'}->get($self->_key({
    class => $class,
    sub => $sub,
    args => $args
  }));
  if($DEBUG) { warn (($out?"hit ":"miss ")."${class}::$sub\n"); }
  return $out;
}

sub _set_cache {
  my ($self,$class,$sub,$args,$value) = @_;

  $self->{'cache'}->set($self->_key({
    class => $class,
    sub => $sub,
    args => $args
  }),$value);
}

1;
