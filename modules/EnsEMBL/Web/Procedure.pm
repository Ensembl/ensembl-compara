package EnsEMBL::Web::Procedure;

# TODO dev disable cache

use strict;
use warnings;

use SiteDefs;
use File::Path;
use Digest::MD5 qw(md5_hex);
use JSON;
use File::Path qw(make_path);

my $DEBUG=0; # TODO: to sitedefs?

sub new {
  my ($proto,$hub,$context) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    variables => {},
    context => $context,
    base => $hub->species_defs->ENSEMBL_TMP_DIR.'/procedure',
    _hub => $hub,
  };
  bless $self,$class;
  return $self;
}

sub set_variables {
  my ($self,$values) = @_;

  $self->{'variables'} = { (%{$self->{'variables'}},%$values) };
}

sub set_params {
  my ($self,@params) = @_;

  my %values;
  $values{$_} = $self->{'_hub'}->params($_) for @params;
  $self->set_variables(\%values);
}

sub objkey {
  my ($self) = @_;

  return {
    variables => $self->{'variables'},
    url => $self->{'_hub'}->url,
    context => $self->{'context'},
    machine => $SiteDefs::ENSEMBL_BASE_URL,
    version => $SiteDefs::ENSEMBL_VERSION,
    boottime => [stat("${SiteDefs::ENSEMBL_SERVERROOT}/ensembl-webcode/conf/started")]->[9],
  };
}

sub hexkey {
  my ($self) = @_;
  my $objkey = $self->objkey();
  my $json = JSON->new->canonical->encode($objkey);
  my $out = md5_hex($json);
  warn "CACHE: key=$json md5=$out\n" if $DEBUG>1;
  warn "CACHE: md5=$out\n" if $DEBUG==1;
  return $out;
}

# We allow upto eight files per directory. Thats 2^8*2^8&2^3 files, ie
# 2^19 (~0.5 million), eight-way set-associative cache.

sub cachefile {
  my ($self) = @_;

  my $key = $self->hexkey();
  my $dir = join('/',$self->{'base'},substr($key,0,2),substr($key,3,2));
  make_path($dir);
  if(opendir(DIR,$dir)) {
    my @files = grep { -f "$dir/$_" and $_ ne $key } readdir(DIR);
    closedir DIR;
    if(@files>8) {
      my @age =
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
        map { [$_,[stat("$dir/$_")]->[9]] } @files;
      unlink "$dir/$age[0]";
    }
  }
  return "$dir/$key";
}

sub cache_get {
  my ($self) = @_;

  my $fn = $self->cachefile();
  unless(-e $fn) {
    warn "CACHE: miss\n" if $DEBUG;
    return undef;
  }
  warn "CACHE: hit\n" if $DEBUG;
  open(FN,$fn) || return undef;
  my $raw;
  { local $/ = undef; $raw = <FN>; }
  close FN;
  my $time = time;
  utime($time,$time,$fn);
  return JSON->new->decode($raw)->{'value'};
}

sub cache_set {
  my ($self,$data) = @_;

  my $fn = $self->cachefile();
  open(FN,'>',"$fn.tmp") || return;
  print FN JSON->new->encode({value => $data});
  close FN;
  rename("$fn.tmp",$fn);
}

sub go {
  my ($self,$callback,@params) = @_;

  my (%args,%cargs);
  my $out = $self->cache_get();
  return $out if defined $out;
  $out = $callback->();
  $self->cache_set($out);
  return $out;
}

1;
