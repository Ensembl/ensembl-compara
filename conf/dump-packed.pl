#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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


use Data::Dumper;
use strict;
use Storable qw(lock_retrieve);

unless(@ARGV) {
  warn '
------------------------------------------------------------------------
Usage:
  
  perl dump-packed.pl {filename} [keys, ...]


Description:

  Dumps the (partial) contents of the frozen file {filename}, if 
  a list of keys are specified then before dumping these keys are
  used to chose a sub tree.

  e.g.
   
  * perl dump-packed.pl [-k] config.packed Homo_sapiens

    dumps the whole human configuration

  * perl dump-packed.pl config.packed Homo_sapiens databases \
                        DATABASE_CORE tables gene

    Prints summary information for human gene table in core database...

  if switch -k is included then dumps just the key of the hash
    useful for "diving" into tree without seeing too much

------------------------------------------------------------------------

';
  exit;
}

my $mode = $ARGV[0] eq '-k';
shift @ARGV if $mode;

my $T = lock_retrieve( shift @ARGV );

foreach( @ARGV ) {
  if( ref( $T ) eq 'HASH' ) {
    if( !exists $T->{$_} ) { print "Key $_ doesn't exist\n\n"; exit; }
    $T = $T->{$_};
  } elsif( ref( $T ) eq 'ARRAY' ) { 
    $_ = int($_);
    if( abs($_) >= @$T ) { print "Index $_ doesn't exist\n\n"; exit; }
    $T = $T->[$_];
  } else {
    print "Cannot iterate into scalar\n\n"; exit; 
  }
}

$Data::Dumper::Indent = 1;
print "
------------------------------------------------------------------------
@ARGV
------------------------------------------------------------------------
";

if( $mode ) {
  print "\t",join("\n\t",sort { lc($a) cmp lc($b) } keys %$T );
} else {
  local $Data::Dumper::Sortkeys = 1;
  my $X = Data::Dumper::Dumper($T);
  print "\n",substr( $X, 8, -2 ),"\n";
}
print "
------------------------------------------------------------------------
";

