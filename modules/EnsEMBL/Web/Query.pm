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
  my ($self,$out,$type,$context,$phase,$extra) = @_;

  $extra ||= [];
  foreach my $k (keys %$type) {
    my $procs = $type->{$k};
    $procs = [$procs] unless ref($procs) eq 'ARRAY';
    foreach my $p (@$procs) {
      $p = [$p] unless ref($p) eq 'ARRAY';
      my @args = @$p;
      my $t = shift @args;
      my $fn = "${phase}_$t";
      if($self->{'impl'}->can($fn)) {
        $self->{'impl'}->$fn($context,$k,$out,@$extra,@args);
      }
    }
  }
}

sub _get {
  my ($self,$type,$context,$sub,$args) = @_;

  my $A = time();
  die "args must be a HASH" unless ref($args) eq 'HASH';
  my @args = ($args);
  $self->_run_phase(\@args,$type,$context,'blockify');
  $args = [$args] unless ref($args) eq 'ARRAY';
  my $out = [];
  my $C = time();
  foreach my $a (@args) { 
    $self->_run_phase($a,$type,$context,'pre_process');
    $self->_check_unblessed($a);
    my $part = $self->{'store'}->_try_get_cache(ref($self),$sub,$a);
    unless(defined $part) {
      my %a_gen = %$a;
      $self->_run_phase(\%a_gen,$type,$context,'pre_generate');
      $part = $self->{'impl'}->$sub(\%a_gen);
      $self->_run_phase($part,$type,$context,'post_generate',[\%a_gen]);
      $self->_check_unblessed($part);
      $self->{'store'}->_set_cache(ref($self),$sub,$a,$part);
    }
    push @$out,@$part;
  }
  my $D = time();
  warn "block gets took ".($D-$C)."s\n" if $DEBUG;
  $self->_run_phase($out,$type,$context,'post_process');
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

sub AUTOLOAD {
  our $AUTOLOAD;
  my $sub = $AUTOLOAD;
  if($sub =~ s/^.*::go(_(\w+))?$/get$1/) {
    my ($self,$context,$args) = @_;
    unless($self->{'impl'}->can($sub)) {
      die "$sub doesn't exist in $self->{'impl'}\n";
    }
    (my $type_sub = $sub) =~ s/^get/type/;
    my $type = {};
    if($self->{'impl'}->can($type_sub)) {
      $type = $self->{'impl'}->$type_sub();
    }
    return $self->_get($type,$context,$sub,$args);
  }
  die "Unknown method $sub\n";
}

1;
