package EnsEMBL::Web::Query;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use JSON;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);
use Time::HiRes qw(time);
use List::Util qw(shuffle);

my $DEBUG = 0;

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
  my ($self,$args,$build) = @_;
      
  my %a_gen = %$args;
  $self->_run_phase(\%a_gen,undef,'pre_generate');
  my $part = $self->{'impl'}->get(\%a_gen);
  $self->_run_phase($part,undef,'post_generate',[\%a_gen]);
  $self->_check_unblessed($part);
  $self->{'store'}->_set_cache(ref($self->{'impl'}),$args,$part,$build);
  return $part;
}

sub go {
  my ($self,$context,$args) = @_;

  my $orig_args = {%$args};
  $args = {%$args};
  my $A = time();
  die "args must be a HASH" unless ref($args) eq 'HASH';
  $self->_run_phase($args,$context,'pre_process');
  my @args = ($args);
  $self->_run_phase(\@args,$context,'split');
  $args = [$args] unless ref($args) eq 'ARRAY';
  my $out = [];
  my $C = time();
  my ($hits,$misses) = (0,0);
  foreach my $a (@args) { 
    $self->_check_unblessed($a);
    my $part = $self->{'store'}->_try_get_cache(ref($self->{'impl'}),$a);
    if(defined $part) {
      $hits++;
      warn "\n\n -- HIT  -- \n ".ref($self->{'impl'})." ".JSON->new->encode($a)."\n\n" if($DEBUG>2);
    } else {
      $part = $self->run_miss($a,0);
      warn "\n\n -- MISS -- \n ".ref($self->{'impl'})." ".JSON->new->encode($a)."\n\n" if($DEBUG>1);
      $misses++;
    }
    push @$out,@$part;
  }
  my $D = time();
  $self->_run_phase($out,$context,'post_process',[$orig_args]);
  my $E = time();
  my $B = time();
  if($DEBUG>2) {
    warn "\n\n ".ref($self->{'impl'})." ".JSON->new->encode($args)."\n\n";
  }
  if($DEBUG) {
    my $name = ref($self->{'impl'});
    $name =~ s/^.*::(.+::.+)$/$1/;
    warn sprintf("%25s: hits=%d misses=%d get+post=total %.3f+%.3f=%.3f\n",
                 $name,$hits,$misses,$D-$C,$E-$D,$B-$A);
  }
  return $out;
}

sub source {
  my ($self,$source) = @_;

  return $self->{'store'}->_source($source);
}

sub precache {
  my ($self,$kind,$i,$n,$r) = @_;

  my $conf = $self->{'impl'}->precache()->{$kind};
  my $fn = "loop_$conf->{'loop'}";
  my $all_parts = $self->{'impl'}->$fn($conf->{'args'});
  my @parts;
  for(my $k=0;$k<@$all_parts;$k++) {
    next unless ($k % $n) == $i;
    push @parts,$all_parts->[$k];
  }
  my $TIME_TOT = 0;
  my $TIME_NUM  = 0;
  $self->{'store'}->open($r||0);
  my $start = time();
  foreach my $args (@parts) {
    my @args = ($args);
    $self->_run_phase(\@args,undef,'split');
    foreach my $a (@args) {
      next if defined $self->{'store'}->_try_get_cache(ref($self->{'impl'}),$a);
      if(time()-$start > 60) {
        $self->{'store'}->close();
        $self->{'store'}->open(-1);
        $start = time();
      }
      my $TIME_A = time;
      $self->run_miss($a,1);
      my $TIME_B = time;
      $TIME_TOT += $TIME_B - $TIME_A;
      $TIME_NUM++;
      warn sprintf("  -> %s %s [%d] %6dms avg %6dms\n",
                    $kind,$a->{'__name'},$i,($TIME_B-$TIME_A)*1000,
                    $TIME_TOT*1000/$TIME_NUM);
    }
  }
  $self->{'store'}->close();      
}

1;
