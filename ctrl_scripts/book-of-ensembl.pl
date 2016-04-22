#! /usr/bin/env perl

use strict;
use warnings;

use Parallel::Forker;

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

use File::Find;
use List::Util qw(min);
use Getopt::Long;

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl;
use EnsEMBL::Web::QueryStore::Source::Adaptors;
use EnsEMBL::Web::QueryStore::Source::SpeciesDefs;
use EnsEMBL::Web::QueryStore;

my $rebuild;
GetOptions('r' => \$rebuild);

sub run1 {
  my ($query,$kind,$i,$n) = @_;

  $i ||= 0;
  $n ||= 1;

  my $SD = EnsEMBL::Web::SpeciesDefs->new();

  my $cache = EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl->new({
    dir => $SiteDefs::ENSEMBL_BOOK_DIR,
    part => $kind,
  });

  my $qs = EnsEMBL::Web::QueryStore->new({
    Adaptors => EnsEMBL::Web::QueryStore::Source::Adaptors->new($SD),
    SpeciesDefs => EnsEMBL::Web::QueryStore::Source::SpeciesDefs->new($SD),
  },$cache,$SiteDefs::ENSEMBL_COHORT);

  my $q = $qs->get($query);
  my $pc = $q->precache($kind,$i,$n,$rebuild);
}

my $forker = Parallel::Forker->new(
  use_sig_chld => 1,
  max_proc => 6
);
$SIG{CHLD} = sub { Parallel::Forker::sig_child($forker); };
$SIG{TERM} = sub { $forker->kill_tree_all('TERM') if $forker && $forker->in_parent; die "Quitting...\n"; };

# Load modules
my @roots = ($SiteDefs::ENSEMBL_WEBROOT);
for(my $i=1;$i<@{$SiteDefs::ENSEMBL_PLUGINS};$i+=2) {
  push @roots,$SiteDefs::ENSEMBL_PLUGINS->[$i];
}
foreach my $root (@roots) {
  my $path = "$root/modules/EnsEMBL/Web/Query";
  next unless -e $path;
  find(sub {
    my $fn = $File::Find::name;
    return unless -f $fn;
    return if $fn =~ m!/\.!;
    $fn =~ s/^$path\//EnsEMBL::Web::Query::/;
    $fn =~ s/\//::/g;
    $fn =~ s/\.pm$//;
    return if $@;
    dynamic_require($fn);
    warn "Loaded $fn\n";
  },$path);
}

# Find packages
my @precache;
sub populate_precache {
  my ($name,$here) = @_;

  push @precache,$name if exists $here->{'precache'} and $name;
  foreach my $k (keys %$here) {
    next unless $k =~ /::$/;
    populate_precache("$name$k",$here->{$k});
  }
}
populate_precache('',\%EnsEMBL::Web::Query::);

# Call pre-cache methods
my %precache;
foreach my $p (@precache) {
  my $module = $p;
  $module =~ s/::$//;
  my $pkg = "EnsEMBL::Web::Query::$module";
  next unless $pkg->can('precache');
  my $r = $pkg->precache;
  foreach my $type (keys %$r) {
    $r->{$type}{'module'} = $module;
    $r->{$type}{'par'} ||= 1;
    $precache{$type} = $r->{$type};
  }
}

# Setup jobs
my @jobs = keys %precache;
@jobs = @ARGV if @ARGV;

foreach my $k (sort { $precache{$a}->{'par'} <=> $precache{$b}->{'par'} } @jobs) {
  my $par = $precache{$k}->{'par'} || 4;
  $par = 4 if $par<4;
  foreach my $i (0..($par-1)) {
    $forker->schedule( run_on_start => sub {
      run1($precache{$k}->{'module'},$k,$i,$par);
    })->ready();
  }
}
$forker->wait_all();

1;
