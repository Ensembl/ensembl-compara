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

use List::Util qw(min);

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl;
use EnsEMBL::Web::QueryStore::Source::Adaptors;
use EnsEMBL::Web::QueryStore;

my $SD = EnsEMBL::Web::SpeciesDefs->new();

my $cache = EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl->new({
  dir => "/tmp/book-of-ensembl",
});

my $ad = EnsEMBL::Web::QueryStore::Source::Adaptors->new($SD);
my $qs = EnsEMBL::Web::QueryStore->new({
  Adaptors => $ad
},$cache,$SiteDefs::ENSEMBL_COHORT);

my $q = $qs->get('GlyphSet::Variation');
#my $pc = $q->precache('ph-short');
my $pc = $q->precache('1kgindels');

1;
