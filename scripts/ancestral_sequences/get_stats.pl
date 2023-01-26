#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

my $dir = ".";
if (@ARGV) {
  $dir = shift;
}

my $dh;
opendir($dh, $dir) or die;
my @fasta_files = sort grep {/\.fa$/} readdir($dh);
closedir($dh);

print join("\t", "FILENAME", "high-conf(ACTG)", "perc", "low-conf(actg)", "perc", "fail(N)", "perc", "insertions(-)", "perc", "no coverage(.)", "perc", "total"), "\n";

foreach my $this_file (@fasta_files) {
  open(my $fasta_fh, '<', $this_file) or die "Cannot open $this_file for reading.\n";
  my $uc = 0;
  my $base_A = 0;
  my $base_C = 0;
  my $base_G = 0;
  my $base_T = 0;
  my $lc = 0;
  my $n = 0;
  my $gaps = 0;
  my $dots = 0;
  while (<$fasta_fh>) {
    next if (/^>/);
    $base_A += ($_ =~ tr/Aa/Aa/);
    $base_C += ($_ =~ tr/Cc/Cc/);
    $base_G += ($_ =~ tr/Gg/Gg/);
    $base_T += ($_ =~ tr/Tt/Tt/);
    $uc += ($_ =~ tr/ACTG/ACTG/);
    $lc += ($_ =~ tr/actg/actg/);
    $n += ($_ =~ tr/Nn/Nn/);
    $gaps += ($_ =~ tr/-/-/);
    $dots += ($_ =~ tr/././);
  }
  close($fasta_fh);
  my $total = $uc + $lc + $n + $gaps + $dots;
  print join("\t", $this_file, (map {sprintf("%d\t%.2f%%", $_, $_*100/$total)} ($uc, $lc, $n, $gaps, $dots)), $total), "\n";
#  print join("\t", $this_file, (map {sprintf("%d\t%.2f%%", $_, $_*100/$total)} ($base_A, $base_C, $base_G, $base_T)), $total), "\n";
}
