#!/usr/local/bin/perl

### A small script which looks through an error log file
### and for each warn line in the logs reports the
### file in which the warn was generated and the counts
### of each line in which a warn occurred.

use strict;
my %X;

while(<STDIN>) {
  if( / at (\S+) line (\d+)\.$/ ) {
    my($S,$L) = ($1,$2);
    $X{$S}{$L}++ unless / redefined at /;
  }
}
foreach my $K (sort keys %X) {
  print "$K\n";
  foreach (sort {$X{$b}<=>$X{$a}} keys %{$X{$K}}) {
    printf "  %6d %d\n", $_, $X{$K}{$_};
  }
}

