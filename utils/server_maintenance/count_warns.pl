#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

