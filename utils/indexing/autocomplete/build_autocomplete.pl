#! /usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);

die "Please specify path to xml files" unless $ARGV[0];

system("cd $Bin; rm -f autocomplete ; gcc -Ofast -flto -march=native -Wall autocomplete.c -o autocomplete -lm") && die "Cannot compile: $!";

my $files = qx(find $ARGV[0] -name \\*.xml);

my $args = "-n 1000000 -c -s all__";

open(AC,"| $Bin/autocomplete $args >$Bin/dict.txt") || die "Cannot run autocomplete";
foreach my $file (split("\n",$files)) {
  chomp $file;
  unless(open(FILE,$file)) {
    print STDERR "No such file '$file'\n";
    next;
  }
  my $species = undef;
  my $any = 0;
  while(<FILE>) {
    $any = 1 if /<field/;
    next unless /<field name="species_name">(.*?)<\/field>/;
    $species = lc($1);
    $species =~ s/ /_/g;
    last;
  }
  close FILE;
  unless($any) {
    print STDERR "Skipping empty file '$file'\n";
    next;
  }
  print AC $file;
  print AC "\@${species}__" if $species;
  print AC "\n";
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

