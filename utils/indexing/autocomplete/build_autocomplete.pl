#! /usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);

die "Please specify path to xml files" unless $ARGV[0];

system("cd $Bin; rm -f autocomplete ; gcc -Ofast -flto -march=native -Wall autocomplete.c -o autocomplete -lm") && die "Cannot compile: $!";

my $files = qx(find $ARGV[0] -name \\*.xml);

my $args = "-n 1000000 -c -s all_";

print "$Bin/autocomplete $args\n";

open(AC,"| $Bin/autocomplete $args >$Bin/dict.txt") || die "Cannot run autocomplete";
foreach my $file (split("\n",$files)) {
  chomp $file;
  my @parts = split(m!/!,$file);
  my @sec = split(m!_!,$parts[-1]);
  my $prefix = join('_',@sec[0..1],'');
  print AC "$file\@$prefix\n";
}
close AC;
open(DICT,"$Bin/dict.txt") || die "Cannot read dict.txt";
open(DICT2,">","$Bin/dict2.txt") || die "Cannot write dict2.txt";
while(<DICT>) {
  my @x = split("\t");
  print DICT2 "$x[0]\n";
}
close DICT;
close DICT2;

1;

