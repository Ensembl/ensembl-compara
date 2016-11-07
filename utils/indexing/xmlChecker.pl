#! /usr/bin/env perl

use strict;
use warnings;

use JSON;
use Digest::MD5 qw(md5_hex);
use Parallel::Forker;
use Fcntl qw(:flock);

my $lockfile = "xml-check.lock";

sub run {
  my ($f) = @_;

  warn ((localtime time)."\nChecking $f [$$]\n");
  my $x = system("xmllint --stream $f");
  open(LOCK,'>',$lockfile);
  flock(LOCK,LOCK_EX);
  die "QUIT ON SIGNAL\n" if $x and $x<128;
  if($x) {
    warn "ERROR: BAD XML IN $f\n";
  }
  flock(LOCK,LOCK_UN);
  close LOCK;
  
  open(OUTPUT,'>',"xml-check-".md5_hex($f).".log") or die "Cannot write";
  print OUTPUT JSON->new->encode({
    size => -s $f,
    status => $x
  });
  close OUTPUT;
}

my ($naughty,$nice,$size) = (0,0,0);
my $start = time;
sub collect {
  my ($f) = @_;

  my $fn = "xml-check-".md5_hex($f).".log";
  my $raw = "";
  open(INPUT,'<',$fn) or die "Cannot read $fn";
  while(<INPUT>) { $raw.=$_; }
  close INPUT;
  unlink $fn;
  my $data = JSON->new->decode($raw);
  if($data->{'status'}) { $naughty++; } else { $nice++; }
  $size += $data->{'size'};
  open(LOCK,'>',$lockfile);
  flock(LOCK,LOCK_EX);
  my $elapsed = time-$start+1;
  warn sprintf("failed=%d passed=%d processed=%dMb rate=%dMb/s (%ds/Gb)\n",
    $naughty,$nice,$size/1024/1024,$size/$elapsed/1024/1024,
    1024*1024*1024*$elapsed/$size);
  flock(LOCK,LOCK_UN);
  close LOCK;
}

my $forker = Parallel::Forker->new(
  use_sig_chld => 1,
  max_proc => 8
);

$SIG{CHLD} = sub { Parallel::Forker::sig_child($forker); };
$SIG{TERM} = sub { $forker->kill_tree_all('TERM') if $forker && $forker->in_parent; die "Quitting...\n"; };

open(FILES,"find input -name \*.xml |") or die "find failed";
while(my $f = <FILES>) {
  chomp $f;
  $forker->schedule( run_on_start => sub { run($f); },
                     run_on_finish => sub { collect($f); }
  )->ready();
}

$forker->wait_all();

1;
