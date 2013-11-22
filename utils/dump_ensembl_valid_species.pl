#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);
use Data::Dumper;

BEGIN {
  unshift @INC, "$Bin/../conf";
  unshift @INC, "$Bin/../";
  require SiteDefs;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

use LoadPlugins;
use EnsEMBL::Web::SpeciesDefs;

my $sd = EnsEMBL::Web::SpeciesDefs->new;
print join "\n", $sd->valid_species, '';

1;
