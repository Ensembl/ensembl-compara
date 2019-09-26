#! /usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);

BEGIN { require "$Bin/../conf/includeSiteDefs.pl" }

use Getopt::Long;
use JSON;
use Parallel::Forker;

use List::Util qw(shuffle);

my ($list,@subparts);
my $workers = 10;
my $verbose = 0;

GetOptions('l' => \$list,'s=s' => \@subparts,'workers=i' => \$workers, 'verbose|v' => \$verbose);
if($list) {
  print qx($Bin/precache.pl --mode=list);
  exit 0;
}
my @params;
push @params,"-s $_" for(@subparts);
push @params,@ARGV;

my $params = join(' ',@params);
  
qx($Bin/precache.pl --mode=start $params);

my @jobs = @ARGV;
if(!@jobs) {
  @jobs = split('\n',qx($Bin/precache.pl --mode=list));
}

foreach my $j (@jobs) {
  warn "preparing $j\n";
  qx($Bin/precache.pl --mode=prepare $j);
}

open(SPEC,'<',"$SiteDefs::ENSEMBL_PRECACHE_DIR/spec") or die;
my $jobs;
{ local $/ = undef; $jobs = JSON->new->decode(<SPEC>); }
close SPEC;
die unless $jobs;
  
my $forker = Parallel::Forker->new(
  use_sig_chld => 1,
  max_proc => $workers,
);
$SIG{CHLD} = sub { Parallel::Forker::sig_child($forker); };
$SIG{TERM} = sub { $forker->kill_tree_all('TERM') if $forker && $forker->in_parent; die "Quitting...\n"; };

my $njobs=@$jobs;
my $ndone=0;

my @lib_dirs;
my @plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS};
while (my ($dir, $name) = splice @plugins, 0, 2) {
 push @lib_dirs, "$dir/modules";
}
push @lib_dirs, @$SiteDefs::ENSEMBL_API_LIBS;
my $libs =  join(' ', map {"-I $_"} @lib_dirs);

sub schedule {
  my ($i) = @_;

  $forker->schedule(
    run_on_start => sub {
      $verbose && warn qq{bsub -I "perl $libs $Bin/precache.pl --mode=index --index=$i"};
      qx(bsub -I "perl $libs $Bin/precache.pl --mode=index --index=$i");
      exit $?;
    },
    run_on_finish => sub {
      my ($self,$exit) = @_;
      if($exit) {
        warn "failed. $exit rescheduling\n";
        schedule($i); 
      } else {
        $ndone++;
      }
      print sprintf("%d/%d (%d%%) done\n",$ndone,$njobs,$ndone*100/$njobs);
    }
  )->ready();
}

foreach my $i (shuffle (0..$#$jobs)) {
  schedule($i);
}
$forker->wait_all();
warn "doing mode=end...\n";
qx($Bin/precache.pl --mode=end);
1;
