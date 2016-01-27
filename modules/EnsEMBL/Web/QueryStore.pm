package EnsEMBL::Web::QueryStore;

use strict;
use warnings;

use JSON;
use Digest::MD5 qw(md5_base64);

use EnsEMBL::Web::Query;

my $DEBUG = 0;
my $DISABLE = 0;

sub new {
  my ($proto,$sources,$cache,$cohort) = @_;

  my $class = ref($proto) || $proto;
  my $self = { sources => $sources, cache => $cache, open => 0 };
  bless $self,$class;
  return $self;
}

sub get {
  my ($self,$query) = @_;

  return EnsEMBL::Web::Query->_new($self,"EnsEMBL::Web::Query::$query");
}

sub _source { return $_[0]->{'sources'}{$_[1]}; }

sub _try_get_cache {
  my ($self,$class,$sub,$args) = @_;

  return undef unless $self->{'open'};
  return undef if $DISABLE;
  my $out = $self->{'cache'}->get({
    class => $class,
    sub => $sub,
    args => $args
  });
  if($DEBUG) { warn (($out?"hit ":"miss ")."${class}::$sub\n"); }
  return $out;
}

sub _set_cache {
  my ($self,$class,$sub,$args,$value) = @_;

  return unless $self->{'open'};
  $self->{'cache'}->set({
    class => $class,
    sub => $sub,
    args => $args
  },$value);
}

sub open {
  my ($self) = @_;

  $self->{'cache'}->cache_open();
  $self->{'open'} = 1;
}

sub close {
  my ($self) = @_;

  $self->{'cache'}->cache_close();
  $self->{'open'} = 0;
}

1;
