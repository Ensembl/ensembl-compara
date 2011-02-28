#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);

BEGIN {
  unshift @INC, "$Bin/../conf";
  unshift @INC, "$Bin/../";
  require SiteDefs;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

require LoadPlugins;
LoadPlugins::plugin(sub {/SiteDefs.pm$/});

print join(":", @INC) . "\n";

1;