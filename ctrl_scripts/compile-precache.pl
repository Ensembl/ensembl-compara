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

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::QueryStore::Cache::PrecacheFile;
use EnsEMBL::Web::QueryStore::Cache::PrecacheBuilder qw(compile_precache);

$EnsEMBL::Web::SpeciesDefs::CONFIG_QUIET = 1;

my @precache = @{compile_precache()};

sub version {
  no strict;
  my ($class) = @_;

  return ${"${class}::VERSION"}||0;
}

my %versions;
foreach my $p (@precache) {
  my $module = $p;
  $module =~ s/::$//;
  my $pkg = "EnsEMBL::Web::Query::$module";
  $versions{$pkg} = version($pkg);
}

unlink $_ for(glob("$SiteDefs::ENSEMBL_BOOK_DIR/replacement.*"));
unlink $_ for(glob("$SiteDefs::ENSEMBL_BOOK_DIR/monitor.*"));

my $cache = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
  dir => $SiteDefs::ENSEMBL_BOOK_DIR,
  base => "replacement",
  write => 1,
});

$cache->cache_open;
# Copy in from candidates
my @candidates = glob("$SiteDefs::ENSEMBL_BOOK_DIR/candidate.*.idx");
if(-e "$SiteDefs::ENSEMBL_BOOK_DIR/precache.idx") {
  push @candidates,"$SiteDefs::ENSEMBL_BOOK_DIR/precache.idx";
}

my (%seen,%lengths);
foreach my $c (@candidates) {
  my $cand = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
    filename => $c
  });
  $cand->cache_open;
  $cache->addgood($cand,\%versions,\%seen,\%lengths);
  $cand->cache_close;
  $cand->remove;
}

sub size {
  my $size = $_[0];

  my @sizes = split(//,"bkMGTP");

  while($size > 4000 and @sizes > 1) {
    $size /= 1024;
    shift @sizes;
  }
  return sprintf("%d%sb",$size,$sizes[0]);
}

warn "added:\n";
foreach my $s (keys %seen) {
  warn "    $seen{$s} $s (".size($lengths{$s}).")\n";
}
warn "optimising\n";
my $opt = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
  dir => $SiteDefs::ENSEMBL_BOOK_DIR,
  base => "optimised",
  write => 1,
});
$opt->cache_open;
foreach my $k (keys %seen) {
  warn "optimising $k\n";
  $opt->addgood($cache,\%versions,undef,undef,$k);
}
$cache->cache_close;
$opt->cache_close;
$cache->remove;

# Launch!
$opt->launch_as("precache");

1;
