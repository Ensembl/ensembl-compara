#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;

open E, "";

while (defined (my $line = <>)) {
  if ($line =~ /^readnames\s+for\s+contig\s+(\d+)\s+.*/) {
    close E;
    open E, ">Extra.set$1";
  } else {
    print E $line;
  }
}

close E;

exit 0;

