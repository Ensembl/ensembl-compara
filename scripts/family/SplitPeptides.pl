#!/usr/local/ensembl/bin/perl

use strict;
use warnings;

my $postfix = 1;

my $copied = 0;
my $id;

#
# Read from STDIN use 2nd col as ids and split ids into 
# files with 100 ids each
#
while(<>) {
  chomp;
  (undef, $id) = split;

  open(FH, ">PeptideSet.$postfix") if($copied == 0);

  print FH "$id\n";
  $copied++;

  if($copied == 100) {
    close FH;
    $copied = 0;
    $postfix++;
  }
}
