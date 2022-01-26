#!/usr/local/bin/perl -w
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


use strict;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use vars qw( $SERVERROOT );
warn $SERVERROOT = dirname( $Bin );

open I,"$SERVERROOT/conf/packed/dhtml.ini";
my %X;
while(<I>) {
  chomp;
  my($k,$v) = /^(\w+)\s*=\s*(\w+)$/;
  $X{$k} = $v;
}

foreach my $d (qw(minified merged packed.0 packed)) {
  opendir DH, "$SERVERROOT/htdocs/$d";
  while(my $f = readdir(DH)) {
    my( $code,$type ) = split /\./,$f;
    next unless exists $X{$type};
    unlink "$SERVERROOT/htdocs/$d/$f" if ($type eq 'css' || $type eq 'js') && $code ne $X{$type};
  }
}
