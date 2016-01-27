package EnsEMBL::Web::Query;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use JSON;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);
use Time::HiRes qw(time);

my $DEBUG = 1;

sub _new {
  my ($proto,$store,$impl) = @_;

  my $class = ref($proto) || $proto;
  dynamic_use($impl);
  $impl = $impl->_new($store);
  my $self = { store => $store, impl => $impl };
  bless $self,$class;
  return $self;
}

sub _check_unblessed {
  my ($self,$args) = @_;
  my $ref = ref($args);
  return unless $ref;
  if($ref eq 'ARRAY') {
    $self->_check_unblessed($_) for(@$args);
  } elsif($ref eq 'HASH') {
    $self->_check_unblessed($_) for(values %$args);
  } else {
    die "Cannot pass/return blessed arguments with query: $ref\n";
  }
}

sub _run_phase {
  my ($self,$out,$context,$phase,$extra) = @_;

  $extra ||= [];
  $self->{'impl'}{'_phase'} = $phase;
  $self->{'impl'}{'_data'} = $out;
  $self->{'impl'}{'_context'} = $context;
  $self->{'impl'}{'_args'} = $extra->[0];
  $self->{'impl'}->fixup();
}

sub run_miss {
  my ($self,$args) = @_;
      
  my %a_gen = %$args;
  $self->_run_phase(\%a_gen,undef,'pre_generate');
  my $part = $self->{'impl'}->get(\%a_gen);
  $self->_run_phase($part,undef,'post_generate',[\%a_gen]);
  $self->_check_unblessed($part);
  $self->{'store'}->_set_cache(ref($self),$args,$part);
  return $part;
}

sub go {
  my ($self,$context,$args) = @_;

  my $orig_args = {%$args};
  $args = {%$args};
  use Data::Dumper;
  local $Data::Dumper::Maxdepth = 3;
  my $A = time();
  die "args must be a HASH" unless ref($args) eq 'HASH';
  $self->_run_phase($args,$context,'pre_process');
  my @args = ($args);
  $self->_run_phase(\@args,$context,'split');
  $args = [$args] unless ref($args) eq 'ARRAY';
  my $out = [];
  my $C = time();
  foreach my $a (@args) { 
    warn Dumper('args',$a);
    $self->_check_unblessed($a);
    my $part = $self->{'store'}->_try_get_cache(ref($self),$a);
    unless(defined $part) {
      $part = $self->run_miss($a);
    }
    push @$out,@$part;
  }
  my $D = time();
  warn "block gets took ".($D-$C)."s\n" if $DEBUG;
  $self->_run_phase($out,$context,'post_process',[$orig_args]);
  my $E = time();
  warn "post took ".($E-$D)."s\n" if $DEBUG;
  my $B = time();
  warn "get took ".($B-$A)."s\n" if $DEBUG;
  warn "post-process ".scalar(@$out)." features\n";
  return $out;
}

sub source {
  my ($self,$source) = @_;

  return $self->{'store'}->_source($source);
}

sub precache {
  my ($self,$kind) = @_;

  my $conf = $self->{'impl'}->precache()->{$kind};
  my $fn = "loop_$conf->{'loop'}";
  my $parts = $self->{'impl'}->$fn($conf->{'args'});
  $self->{'store'}->open();
  my $start = time();
  foreach my $args (@$parts) {
    my @args = ($args);
    $self->_run_phase(\@args,undef,'split');
    foreach my $a (@args) {
      next if defined $self->{'store'}->_try_get_cache(ref($self),$a);
      warn "  -> ".$a->{'__name'}."\n";
      if(time()-$start > 60) {
        $self->{'store'}->close();
        $self->{'store'}->open();
        $start = time();
      }
      $self->run_miss($a);
    }
  }
  $self->{'store'}->close();      
}

1;
