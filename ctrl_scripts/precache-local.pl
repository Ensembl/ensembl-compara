#! /usr/bin/env perl

use strict;
use warnings;

my $ENSEMBL_ROOT;

BEGIN {
  use FindBin qw($Bin);
  use File::Basename qw( dirname );
  $ENSEMBL_ROOT = dirname( $Bin );
  $ENSEMBL_ROOT =~ s/\/utils$//;
  unshift @INC, "$ENSEMBL_ROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use Getopt::Long;
use JSON;
use Parallel::Forker;

my ($list,@subparts);

GetOptions('l' => \$list,'s=s' => \@subparts);
if($list) {
  print qx($Bin/precache.pl --mode=list);
  exit 0;
}
my @params;
push @params,"-s $_" for(@subparts);
push @params,@ARGV;

my $params = join(' ',@params);
  
qx($Bin/precache.pl --mode=start $params);
open(SPEC,'<',"$SiteDefs::ENSEMBL_BOOK_DIR/spec") or die;
my $jobs;
{ local $/ = undef; $jobs = JSON->new->decode(<SPEC>); }
close SPEC;
die unless $jobs;
  
my $forker = Parallel::Forker->new(
  use_sig_chld => 1,
  max_proc => 20 
);
$SIG{CHLD} = sub { Parallel::Forker::sig_child($forker); };
$SIG{TERM} = sub { $forker->kill_tree_all('TERM') if $forker && $forker->in_parent; die "Quitting...\n"; };

my $ndone=0;
foreach my $i (reverse (0..$#$jobs)) {
  $forker->schedule(
    run_on_start => sub {
      qx($Bin/precache.pl --mode=index --index=$i);
    },
    run_on_finish => sub {
      $ndone++;
      print sprintf("%d/%d (%d%%) done\n",$ndone,$#$jobs+1,$ndone*100/@$jobs);
    }
  )->ready();
}
$forker->wait_all();
qx($Bin/precache.pl --mode=end);
1;
