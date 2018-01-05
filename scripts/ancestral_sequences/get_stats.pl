#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

opendir(DIR, $dir) or die;
my @fasta_files = sort grep {/\.fa$/} readdir(DIR);
closedir(DIR);

print join("\t", "FILENAME", "high-conf(ACTG)", "perc", "low-conf(actg)", "perc", "fail(N)", "perc", "insertions(-)", "perc", "no coverage(.)", "perc", "total"), "\n";

foreach my $this_file (@fasta_files) {
  open(FASTA, $this_file) or die "Cannot open $this_file for reading.\n";
  my $uc = 0;
  my $base_A = 0;
  my $base_C = 0;
  my $base_G = 0;
  my $base_T = 0;
  my $lc = 0;
  my $n = 0;
  my $gaps = 0;
  my $dots = 0;
  while (<FASTA>) {
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
  close(FASTA);
  my $total = $uc + $lc + $n + $gaps + $dots;
  print join("\t", $this_file, (map {sprintf("%d\t%.2f%%", $_, $_*100/$total)} ($uc, $lc, $n, $gaps, $dots)), $total), "\n";
#  print join("\t", $this_file, (map {sprintf("%d\t%.2f%%", $_, $_*100/$total)} ($base_A, $base_C, $base_G, $base_T)), $total), "\n";
}
