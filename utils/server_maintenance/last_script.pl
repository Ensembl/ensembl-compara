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


### A short script which parses an error log and reports the PID
### of the child along with the last SCRIPT/ENDSCR line in the
### log file - entries are of the form:
### == time script - for running PIDs
### ** time (last execution time) script - for waiting PIDs
### ## time (last execution time) script - for terminated PIDs

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

[w3adm@web-3-02 utils]$ cat last_script.pl
#!/usr/local/bin/perl
use strict;

my %X = ();

while(<STDIN>) {
  if( /^SCRIPT:[^:]+:(\d+)\s+(\d+-\d+-\d+ \d+:\d+:\d+) (\S+)/ ) {
    $X{$1} = "== $2 $3";
  } elsif( /^ENDSCR:[^:]+:(\d+)\s+(\d+-\d+-\d+ \d+:\d+:\d+)\s+(\d+\.\d+) (\S+)/ ) {
    $X{$1} = "** $2 $3 $4";
  } elsif( /^Child (\d+): - reaped/ && $X{$1} ) {
    substr( $X{$1},0,2 ) = '##';
  }
}

foreach (sort keys %X) {
  print "$_\t$X{$_}\n";
}

