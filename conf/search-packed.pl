#! /usr/bin/env perl

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

use strict;
use warnings;

# Tool for searching inside config.packed. Takes slash-separated list of
# keys to search for. * means that all keys are taken and the key added
# to the context. Prints output as 'context type value' where type is
# k for a hash key, v for a string value, a for an array (its length).
# Arrays are otherwise treated as if hashes with integer keys. Context
# is printed as a slash separated list of values used for * in that row.
# For example, to find glyphsets specified by a format key in an analysis:
#
# $ ./search-packed.pl '*/databases/*/tables/*/analyses/*/format'
# ...
# Latimeria_chalumnae/DATABASE_OTHERFEATURES/data_file/coelacanth_bwa v bam
# ...
#
# As an alternative, all keys, values and arrays can be searched for a
# string by specifying a final path component '*<match>', for example
#
# $ ./search-packed.pl 'Homo_sapiens/*segway'

use FindBin;
use Storable qw(retrieve);

my $pattern = shift @ARGV;
my @pattern;

@pattern = split('/',$pattern) if $pattern;
my $match = pop @pattern if @pattern and $pattern[-1] =~ /^\*/;

my @s = ([[],retrieve("$FindBin::Bin/config.packed")]);
foreach my $p (@pattern) {
  my @s2;
  foreach my $s (@s) {
    if($p eq '*') {
      if(ref($s->[1]) eq 'HASH') {
        foreach my $k (keys %{$s->[1]}) {
          push @s2,[[@{$s->[0]},$k],$s->[1]{$k}];
        }
      } elsif(ref($s->[1]) eq 'ARRAY') {
        foreach my $i (0..$#{$s->[1]}) {
          push @s2,[[@{$s->[0]},$i],$s->[1][$i]];
        }
      }
    } elsif(ref($s->[1]) eq 'HASH' and exists $s->[1]{$p}) {
      push @s2,[$s->[0],$s->[1]{$p}];
    } elsif(ref($s->[1]) eq 'ARRAY' and $p =~ /^\d+$/ and $p < @{$s->[1]}) {
      push @s2,[$s->[0],$s->[1][$p]];
    }
  }
  @s = @s2;
}

sub match {
  my ($path,$data,$type,$match,$out) = @_;

  if(ref($data) eq 'HASH') {
    foreach my $k (keys %$data) {
      if($k =~ /$match/) {
        push @$out,[[@$path,$k],undef];
      }
      match([@$path,$k],$data->{$k},$type,$match,$out);
    }
  }
}

my $type;
if($match) {
  $match =~ s/^([*])//;
  $type = $1;
  my @s2;
  foreach my $s (@s) {
    match($s->[0],$s->[1],$type,$match,\@s2);
  }
  @s = @s2;
}
foreach my $s (@s) {
  if(!defined($s->[1])) {
    print join('/',@{$s->[0]})." f\n";
  } elsif(ref($s->[1]) eq 'HASH') {
    foreach my $k (keys %{$s->[1]}) {
      print join('/',@{$s->[0]})." k $k\n";
    }
  } elsif(ref($s->[1]) eq 'ARRAY') {
    print join('/',@{$s->[0]})." a ".scalar(@{$s->[1]})."\n";
  } else {
    my $v = $s->[1];
    $v = 'undef' unless defined $v;
    print join('/',@{$s->[0]})."\tv\t$v\n";
  }
}

1;
