package EnsEMBL::Web::QueryStore;

use strict;
use warnings;

use Carp qw(cluck);
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

sub _clean_args {
  my ($self,$args) = @_;

  my %out = %$args;
  delete $out{'__name'};
  return \%out;
}

sub version {
  no strict;
  my ($self,$class) = @_;

  return ${"${class}::VERSION"}||0;
}

sub _try_get_cache {
  my ($self,$class,$args) = @_;

  if(!$self->{'open'} && $DEBUG) {
    cluck("get on closed cache");
  }
  return undef unless $self->{'open'};
  return undef if $DISABLE;
  my $out = $self->{'cache'}->get($class,$self->version($class),{
    class => $class,
    args => $self->_clean_args($args),
  });
  if($DEBUG) { warn (($out?"hit ":"miss ")."${class}\n"); }
  return $out;
}

sub _set_cache {
  my ($self,$class,$args,$value) = @_;

  return unless $self->{'open'};
  $self->{'cache'}->set($class,$self->version($class),{
    class => $class,
    args => $self->_clean_args($args)
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
