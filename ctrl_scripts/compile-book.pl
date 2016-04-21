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

EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl->new({
  dir => $SiteDefs::ENSEMBL_BOOK_DIR,
  replace => 1,
})->merge;

1;
