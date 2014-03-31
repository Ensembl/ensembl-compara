#! /usr/bin/env perl

use strict;
use warnings;

my $freq = qq(
E 21912
T 16587
A 14810
O 14003
I 13318
N 12666
S 11450
R 10977
H 10795
D 7874
L 7253
U 5246
C 4943
M 4761
F 4200
Y 3853
W 3819
G 3693
P 3316
B 2715
V 2019
K 1257
X 315
Q 205
J 188
Z 128
);

my (%freq,$total);
foreach (split("\n",$freq)) {
  next unless /(\S+)\s+(\S+)/;
  $freq{lc $1} = 0+$2;
  $total += 0+$2;
}
my $out;
foreach my $c ('a'..'z') {
  my $num = int(-100*log($freq{$c}/$total)/log(10));
  $out .= sprintf("%3d,",$num);
  $out .= "\n" if $c eq 'm';
}
$out =~ s/,$//;
print "$out\n";

