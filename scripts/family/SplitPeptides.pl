#!/usr/local/ensembl/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $postfix = 1;

my $maxids = 50;
my $copied = 0;
my $id;

GetOptions('maxids=i' => \$maxids);

#
# Read from STDIN use 2nd col as ids and split ids into 
# files with 100 ids each
#
while(<>) {
  chomp;
  ($id) = split;

  open(FH, ">PeptideSet.$postfix") if($copied == 0);

  print FH "$id\n";
  $copied++;

  if($copied == $maxids) {
    close FH;
    $copied = 0;
    $postfix++;
  }
}
