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

use Getopt::Long;

my $description = qq{
  compare_beds.pl [options] <BED_FILE_1> <BED_FILE_2> [mode]

  where mode can be:
  (*) all (default): will output regions specific to either 
        file and regions in common
  (*) intersection: only prints regions in common

  where options can be:
  (*) low_mem: stores BED data for 1 chromsome at a time. This
        option reduces the memory requirements of this
        application but increases the execution time.
  (*) merge: merges contiguous features
  (*) stats-only: do not output the features, only the stats lines
  (*) verbose: shows progress

  This script can be used to compare the overlap between two
  BED files. Overlaps within a BED file are removed, i.e.
  regions 1:123-135 and 1:130-150 are internally transformed
  to one single 1:123-150 region. If the two files are:
  FILE1:
  1	123	135
  1	130	150

  FILE2:
  1	132	170

  The output will be:

  # Comparing FILE1 (FIRST) vs FILE2 (SECOND)
  1       123     132     FIRST
  1       132     150     OVERLAP
  1       150     170     SECOND

  By default ("all" mode) the script prints some stats about
  overlaps at the end or the output:
  
  # FIRST: 9 ; BOTH: 18 ; SECOND: 20
  # FIRST: 19.15%; BOTH: 38.30%; SECOND: 42.55%
  # FIRST OVERLAP: 66.67%; SECOND OVERLAP: 47.37%
  
  The first line means that there are 9 bp covered by features
  in the first file only, 18 bp by features in both files and
  20 bp by features in the secodn file only. The second line
  express these values as a percentage of all the bp covered by
  all the features and the third line express the percentage of
  the features in the first (second) file that overlap the
  features in the other file.

  The programs exits if it finds regions in NT contigs and
  regions in random chromosomes. This is to avoid comparing
  Ensembl coordinates (NT contigs) with UCSC ones (random
  chromosomes).

};

my $low_mem = 0;
my $merge = 0;
my $stats_only = 0;
my $verbose = 0;

GetOptions(
  'low_mem|low-mem|lowmem' => \$low_mem,
  'merge' => \$merge,
  'stats_only|stats-only|statsonly' => \$stats_only,
  'verbose' => \$verbose,
  );

my ($file1, $file2, $mode) = @ARGV;

if (!$file1 or !$file2 or !-e $file1 or !-e $file2) {
  die $description;
}

my $contains_NT_contigs = 0;
my $contains_random_chromosomes = 0;


my ($names1, $names2);
my ($all_features1, $all_features2);
if ($low_mem) {
  if ($verbose) { print STDERR "Reading chromosome names\n" };
  $names1 = get_chr_names($file1);
  if ($file1 eq $file2) {
    $names2 = $names1;
  } else {
    $names2 = get_chr_names($file2);
  }

} else {
  if ($verbose) { print STDERR "Reading all features\n" };
  $all_features1 = read_bed_file($file1);
  $all_features2 = read_bed_file($file2) unless ($file1 eq $file2);
  foreach my $chr (keys %$all_features1) {
    $names1->{$chr} = 1;
  }
  foreach my $chr (keys %$all_features2) {
    $names2->{$chr} = 1;
  }

}

my $all_names = {};
foreach my $chr (keys %$names1, keys %$names2) {
  $all_names->{$chr} = 1;
}


if ($contains_NT_contigs and $contains_random_chromosomes) {
  die "The files contain NT contigs and random chromsomes!\n";
}

if (!$mode) {
  $mode = "all";
  print "# Comparing $file1 (FIRST) vs $file2 (SECOND)\n";
} else {
  $mode = "intersection";
  print "# Comparing $file1 (FIRST) vs $file2 (SECOND) -- intersection mode\n";
}

my ($first, $second, $both) = (0, 0, 0);

foreach my $chr (sort {if ($a=~/^\d+$/ and $b=~/^\d+$/) { return $a <=> $b } else { return $a cmp $b}} keys %$all_names) {
  next if ($mode eq "intersection" and (!defined($names1->{$chr}) or !defined($names2->{$chr})));

  if ($verbose) { print STDERR "Comparing features on $chr...\n" };
  
  my $features1 = {};
  my $features2 = {};

  if ($all_features1) {
    $features1 = $all_features1;
  } elsif (defined($names1->{$chr})) {
    $features1 = read_bed_file($file1, $chr);
  }
  # Special use case: file1 and file2 are the same: the
  # script will is used to get rid of the overlaps
  if ($file1 eq $file2) {
    foreach my $feature (@{$features1->{$chr}}) {
      my ($start1, $end1) = @{$feature};
      print join("\t", $chr, $start1, $end1, "OVERLAP"), "\n" unless ($stats_only);
      $both += $end1 - $start1;
    }
    next;
  }

  if ($all_features2) {
    $features2 = $all_features2;
  } elsif (defined($names2->{$chr})) {
    $features2 = read_bed_file($file2, $chr);
  }

  my $last_end = 0;
  my $max_i = 0;
  if ($features1->{$chr}) {
    $max_i = scalar(@{$features1->{$chr}});
  }
  my $max_j = 0;
  if ($features2->{$chr}) {
    $max_j = scalar(@{$features2->{$chr}});
  }
  my $j = 0;
  if ($mode eq "intersection") {
    for (my $i = 0; $i < $max_i; $i++) {
      my ($start1, $end1) = @{$features1->{$chr}->[$i]};
      for (; $j < $max_j; $j++) {
        my ($start2, $end2) = @{$features2->{$chr}->[$j]};
        if ($end2 <= $start1) {
          next;
        }
        if ($start2 >= $end1) {
          last;
        }
        my $start_overlap = ($start1 > $start2)? $start1 : $start2;
        my $end_overlap = ($end1 < $end2) ? $end1 : $end2;
        print join("\t", $chr, $start_overlap, $end_overlap, "OVERLAP"), "\n" unless ($stats_only);
      }
      $j-- if ($j>0);
    }
  } elsif ($mode eq "all") {
    my $i = 0;
    my $j = 0;
    my ($start1, $end1);
    if ($features1->{$chr}) {
      ($start1, $end1) = @{$features1->{$chr}->[$i]};
    }
    my ($start2, $end2);
    if ($features2->{$chr}) {
      ($start2, $end2) = @{$features2->{$chr}->[$j]};
    }
    while ($i < $max_i and $j < $max_j) {
#       print "$start1 - $end1 - $start2 - $end2\n";
      if ($start1 >= $end2) {
        print join("\t", $chr, $start2, $end2, "SECOND"), "\n" unless ($stats_only);
        $second += $end2 - $start2;
        $j++;
        ($start2, $end2) = @{$features2->{$chr}->[$j]} if ($j < $max_j);
      } elsif ($start2 >= $end1) {
        print join("\t", $chr, $start1, $end1, "FIRST"), "\n" unless ($stats_only);
        $first += $end1 - $start1;
        $i++;
        ($start1, $end1) = @{$features1->{$chr}->[$i]} if ($i < $max_i);
      } elsif ($start1 > $start2) {
        print join("\t", $chr, $start2, $start1, "SECOND"), "\n" unless ($stats_only);
        $second += $start1 - $start2;
        $start2 = $start1;
      } elsif ($start1 < $start2) {
        print join("\t", $chr, $start1, $start2, "FIRST"), "\n" unless ($stats_only);
        $first += $start2 - $start1;
        $start1 = $start2;
      } elsif ($end1 < $end2) {
        print join("\t", $chr, $start1, $end1, "OVERLAP"), "\n" unless ($stats_only);
        $both += $end1 - $start1;
        $start2 = $end1;
        $i++;
        ($start1, $end1) = @{$features1->{$chr}->[$i]} if ($i < $max_i);
      } elsif ($end1 > $end2) {
        print join("\t", $chr, $start1, $end2, "OVERLAP"), "\n" unless ($stats_only);
        $both += $end2 - $start1;
        $start1 = $end2;
        $j++;
        ($start2, $end2) = @{$features2->{$chr}->[$j]} if ($j < $max_j);
      } else {
        print join("\t", $chr, $start1, $end1, "OVERLAP"), "\n" unless ($stats_only);
        $both += $end1 - $start1;
        $i++;
        $j++;
        ($start1, $end1) = @{$features1->{$chr}->[$i]} if ($i < $max_i);
        ($start2, $end2) = @{$features2->{$chr}->[$j]} if ($j < $max_j);
      }
    }
    while ($i < $max_i) {
      print join("\t", $chr, $start1, $end1, "FIRST"), "\n" unless ($stats_only);
      $first += $end1 - $start1;
      $i++;
      ($start1, $end1) = @{$features1->{$chr}->[$i]} if ($i < $max_i);
    }
    while ($j < $max_j) {
      print join("\t", $chr, $start2, $end2, "SECOND"), "\n" unless ($stats_only);
      $second += $end2 - $start2;
      $j++;
      ($start2, $end2) = @{$features2->{$chr}->[$j]} if ($j < $max_j);
    }
  }
}

if ($mode eq "all") {
  print "# FIRST: $first ; BOTH: $both ; SECOND: $second\n";
  printf "# FIRST: %.2f%%; BOTH: %.2f%%; SECOND: %.2f%%\n",
      ($first*100/ ($first + $both + $second)),
      ($both*100/ ($first + $both + $second)),
      ($second*100/ ($first + $both + $second));
  my $first_overlap = 0;
  if ($first + $both > 0) {
    $first_overlap = $both * 100/ ($first + $both);
  }
  my $second_overlap = 0;
  if ($second + $both > 0) {
    $second_overlap = $both * 100/ ($second + $both);
  }
  printf "# FIRST OVERLAP: %.2f%%; SECOND OVERLAP: %.2f%%\n",
      $first_overlap, $second_overlap;
}

sub read_bed_file {
  my ($file, $this_chr) = @_;
  my $features;

  open(FILE, $file);
  if ($this_chr) {
    while (<FILE>) {
      next if (/^#/ or /^track/);
      my ($chr, $start, $end) = split(/\s+/, $_);
      $chr =~ s/^chr//;
      next if ($chr ne $this_chr);
      # If another feature starts at the same position, keeps the longest one
      if (!exists($features->{$chr}->{$start}) or $features->{$chr}->{$start} < $end) {
        $features->{$chr}->{$start} = $end;
      }
    }
  } else {
    while (<FILE>) {
      next if (/^#/ or /^track/);
      my ($chr, $start, $end) = split(/\s/, $_);
      next if ($chr eq "");
      $chr =~ s/^chr//;
      $contains_random_chromosomes = 1 if ($chr =~ /random/);
      $contains_NT_contigs = 1 if ($chr =~ /NT/);
      # If another feature starts at the same position, keeps the longest one
      if (!exists($features->{$chr}->{$start}) or $features->{$chr}->{$start} < $end) {
        $features->{$chr}->{$start} = $end;
      }
    }
  }
  close(FILE);

  my $sorted_features;
  ## Merges overlapping features
  foreach my $chr (keys %$features) {
    my @all_starts = sort {$a <=> $b} keys %{$features->{$chr}};
    my $last_end = -1;
    for (my $i = 0; $i < @all_starts; $i++) {
      my $start = $all_starts[$i];
      # with ($start > $last_end) -> merges contiguous features
      # with ($start >= $last_end) -> leaves contiguous features separated
      if ($start > $last_end or ($start == $last_end and !$merge)) {
        $last_end = $features->{$chr}->{$start};
        push(@{$sorted_features->{$chr}}, [$start, $last_end]);
      } elsif ($features->{$chr}->{$start} > $last_end) {
        $last_end = $features->{$chr}->{$start};
        $sorted_features->{$chr}->[-1]->[1] = $last_end;
      }
    }
  }

  return $sorted_features;
}

sub get_chr_names {
  my ($file) = @_;
  my $names = {};

  open(FILE, $file);
  while (<FILE>) {
    next if (/^#/ or /^track/);
    my ($chr, $start, $end) = split(/\s/, $_);
    $chr =~ s/^chr//;
    next if ($chr eq "");
    $contains_random_chromosomes = 1 if ($chr =~ /random/);
    $contains_NT_contigs = 1 if ($chr =~ /NT/);
    $names->{$chr} = 1;
  }
  close(FILE);

  return $names;
}

