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

use List::Util qw(min);

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl;
use EnsEMBL::Web::QueryStore::Source::Adaptors;
use EnsEMBL::Web::QueryStore;

sub run1 {
  my ($query,$kind) = @_;

  my $SD = EnsEMBL::Web::SpeciesDefs->new();

  my $cache = EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl->new({
    dir => "/tmp/book-of-ensembl",
  });

  my $ad = EnsEMBL::Web::QueryStore::Source::Adaptors->new($SD);
  my $qs = EnsEMBL::Web::QueryStore->new({
    Adaptors => $ad
  },$cache,$SiteDefs::ENSEMBL_COHORT);

  my $q = $qs->get($query);
  my $pc = $q->precache($kind);
}

my $forker = Parallel::Forker->new(
  use_sig_chld => 1,
  max_proc => 5
);
$SIG{CHLD} = sub { Parallel::Forker::sig_child($forker); };
$SIG{TERM} = sub { $forker->kill_tree_all('TERM') if $forker && $forker->in_parent; die "Quitting...\n"; };

$forker->schedule( run_on_start => sub {
  run1('GlyphSet::Variation','1kgindels');
})->run();
$forker->schedule( run_on_start => sub {
  run1('GlyphSet::Variation','ph-short');
})->run();
$forker->schedule( run_on_start => sub {
  run1('GlyphSet::Marker','markers');
})->run();
$forker->schedule( run_on_start => sub {
  run1('GlyphSet::AssemblyException','assemblyexceptions');
})->run();

$forker->wait_all();

1;
