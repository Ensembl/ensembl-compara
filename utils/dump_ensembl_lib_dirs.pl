#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);

BEGIN {
  unshift @INC, "$Bin/../conf";
  unshift @INC, "$Bin/../";
  require SiteDefs;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

use LoadPlugins;

my @libs = grep { ref $_ ne 'CODE' } @INC; ## ugh, why are there coderefs in @INC!?

print join(":", @libs) . "\n";

1;
