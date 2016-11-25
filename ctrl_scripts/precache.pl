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
  open OLDERR,'>&STDERR';
  eval{
    local *STDERR;
    open(STDERR,">/dev/null");
    require SiteDefs;
    close STDERR;
  };  
  open(STDERR,">&OLDERR");
  close OLDERR;

  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::QueryStore::Cache::PrecacheBuilder qw(compile_precache identity);

use List::Util qw(min shuffle);
use Getopt::Long;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::QueryStore::Cache::PrecacheFile;
use EnsEMBL::Web::QueryStore::Source::Adaptors;
use EnsEMBL::Web::QueryStore::Source::SpeciesDefs;
use EnsEMBL::Web::QueryStore;

use EnsEMBL::Web::SpeciesDefs;
$EnsEMBL::Web::SpeciesDefs::CONFIG_QUIET = 1;


sub merge {
  my ($limit) = @_;

  my $id = identity();
  my $cache = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
    dir => $SiteDefs::ENSEMBL_BOOK_DIR,
    base => "generate.merged.$id",
    write => 1,
  });

  my $select = $cache->select(
    "$SiteDefs::ENSEMBL_BOOK_DIR/ready.*","ready","merging.$id",2,$limit
  );

  unless($select) {
    $cache->remove;
    return;
  }

  foreach my $part (@$select) {
    $cache->addall($part);
    $part->remove;
  }
  $cache->launch_as("ready.merged",1);
}

sub run1 {
  my ($query,$kind,$i,$n,$subparts) = @_;

  $i ||= 0;
  $n ||= 1;

  my $id = identity();
  my $SD = EnsEMBL::Web::SpeciesDefs->new();

  my $cache = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
    dir => $SiteDefs::ENSEMBL_BOOK_DIR,
    base => "generate.$kind.$id",
    write => 1,
  });

  my $qs = EnsEMBL::Web::QueryStore->new({
    Adaptors => EnsEMBL::Web::QueryStore::Source::Adaptors->new($SD),
    SpeciesDefs => EnsEMBL::Web::QueryStore::Source::SpeciesDefs->new($SD),
  },$cache,$SiteDefs::ENSEMBL_COHORT);

  my $q = $qs->get($query);
  my $pc = $q->precache($kind,$i,$n,$subparts);
  $cache->launch_as("ready.$kind",1);
  
  merge(3);
}

my (@subparts,$mode,$index);
GetOptions('s=s' => \@subparts,'mode=s' => \$mode,'index=s' => \$index);
die "No mode specified" unless $mode;

# Call pre-cache methods
my (%precache,%parts);
foreach my $p (@{compile_precache()}) {
  my $module = $p;
  $module =~ s/::$//;
  my $pkg = "EnsEMBL::Web::Query::$module";
  next unless $pkg->can('precache');
  my $r = $pkg->precache;
  foreach my $type (keys %$r) {
    $r->{$type}{'module'} = $module;
    $precache{$type} = $r->{$type};
    $parts{$type} = $r->{$type}{'parts'} || 100;
  }
}

my @jobs = keys %precache;
@jobs = @ARGV if @ARGV;

# Parse subparts arguments / list jobs
my %subparts;
foreach my $s (@subparts) {
  my ($k,$v) = split('=',$s,2);
  $subparts{$k} = $v;
}
if($mode eq 'list') {
  print join("\n",@jobs,'');
  exit 0;
}

unlink "$SiteDefs::ENSEMBL_BOOK_DIR/spec" if $mode eq 'start';
# Build specs
my @procs;
foreach my $k (@jobs) {
  die "No such job $k" unless $parts{$k};
  my $par = $parts{$k};
  foreach my $i (0..($par-1)) {
    push @procs,[$precache{$k}->{'module'},$k,$i,$par,\%subparts];
  }
}

if($mode eq 'start') {
  # Remove old files
  unlink $_ for(glob("$SiteDefs::ENSEMBL_BOOK_DIR/generate.*"));
  unlink $_ for(glob("$SiteDefs::ENSEMBL_BOOK_DIR/ready.*"));
  unlink $_ for(glob("$SiteDefs::ENSEMBL_BOOK_DIR/merging.*"));
  unlink $_ for(glob("$SiteDefs::ENSEMBL_BOOK_DIR/selected.*"));
}

if($mode eq 'start') {
  warn $SiteDefs::ENSEMBL_BOOK_DIR;
  open(SPEC,'>',"$SiteDefs::ENSEMBL_BOOK_DIR/spec") or die;
  print SPEC JSON->new->encode(\@procs);
  close SPEC;
  exit 0;
}

if($mode eq 'index') {
  my $task;
  {
    local $/ = undef;
    open(SPEC,'<',"$SiteDefs::ENSEMBL_BOOK_DIR/spec") or die;
    my $spec = JSON->new->decode(<SPEC>);
    close SPEC;
    $task = $spec->[$index];
  }
  die unless $task;
  run1(@$task);
  exit 0;
}

if($mode eq 'end') {
  merge();

  # Rename ready as candidate for compilation
  my @r = glob("$SiteDefs::ENSEMBL_BOOK_DIR/ready.*.idx");
  die "None ready" unless @r;
  die "Multiple ready" if @r >1;
  my $ready = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
    filename => $r[0],
    write => 1,
  });
  $ready->launch_as("candidate.$$");
}

1;
