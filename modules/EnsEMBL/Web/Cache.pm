package EnsEMBL::Web::Cache;

## This module overwrites several subroutines from Cache::Memcached
## to be able to track and monitor memcached statistics better
## this applies only when debug mode is on

use strict;
use warnings;
use Data::Dumper;
use EnsEMBL::Web::SpeciesDefs;
use base 'Cache::Memcached';
use fields 'default_exptime';

sub new {
  my $class = shift;
  my $species_defs = new EnsEMBL::Web::SpeciesDefs;
  my %memcached    = $species_defs->multiX('ENSEMBL_MEMCACHED');

  return undef
    unless %memcached;

  my %args = (
    servers         => $memcached{servers},
    debug           => $memcached{debug},
    default_exptime => $memcached{default_exptime},
    @,
  );

  my $default_exptime = delete $args{default_exptime};
    
  my $self = $class->SUPER::new(\%args);

  $self->{default_exptime} = $default_exptime;
  return $self;
}

sub set {
  my $self = shift;
  my ($key, $value, $exptime) = @_;

  if ($self->{debug}) {
    my $debug_key_list = $self->SUPER::get('debug_key_list') || {};
    $debug_key_list->{$key} = {} unless $debug_key_list->{$key};
    $debug_key_list->{$key}{set_time} ||= localtime;
    $debug_key_list->{$key}{upd_time}   = localtime;
    $debug_key_list->{$key}{upd_cntr}++;
    $debug_key_list->{$key}{get_time}   = 0;
    $debug_key_list->{$key}{get_cntr}   = 0;
    $self->SUPER::set('debug_key_list', $debug_key_list);
  }
  
  $self->SUPER::set($key, $value, $exptime || $self->{default_exptime});
}

sub get {
  my $self = shift;
  my $key  = shift;

  if ($self->{debug} && (my $debug_key_list = $self->SUPER::get('debug_key_list'))) {
    $debug_key_list->{$key} ||= {};
    $debug_key_list->{$key}{get_time} = localtime;
    $debug_key_list->{$key}{get_cntr}++;
    $self->SUPER::set('debug_key_list', $debug_key_list);
  }
  
  return $self->SUPER::get($key);
}

sub delete {
  my $self = shift;
  my $key  = shift;

  if ($self->{debug} && (my $debug_key_list = $self->SUPER::get('debug_key_list'))) {
    delete $debug_key_list->{$key};
    $self->SUPER::set('debug_key_list', $debug_key_list);
  }

  return $self->SUPER::remove($key, @_);
}

*remove = \&delete;

1;