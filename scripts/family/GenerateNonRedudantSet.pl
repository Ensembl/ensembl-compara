#!/usr/local/ensembl/bin/perl -w

use strict;

# to work you have to get the pmatch output from /nfs/disk5/ms2/bin/pmatch
# EXIT STATUS
# 1 Query id and target id have been stored in 2 different indices.

my ($fasta,$fastaindex,$fasta_nr,$redundant_file) = @ARGV;


my $pmatch_file = "/acari/work7a/abel/family_19_2/tmp/metazoa_19_2.pmatch.nr.gz";
#my $pmatch_file = "test2";

if ($pmatch_file =~ /\.gz/) {
  open PM, "gunzip -c $pmatch_file|" ||
    die "$pmatch_file: $!";
} else {
  open PM, $pmatch_file ||
    die "$pmatch_file: $!";
}

my @redundancies;
my %stored_at_index;
my $index = 0;

# The whole process that results are sorted by $qid and $tid which is basically what pmatch
# output does. If the result appears in a randon way (no reason for that though) the process may break
# with exit code 1

while (my $line = <PM>) {
  $index++;
  chomp $line;
  my ($length, $qid, $qstart, $qend, $qperc, $qlen, $tid, $tstart, $tend, $tperc, $tlen) = split /\s+/,$line;
  next if ($qid eq $tid);
  next unless ($length == $qlen && $length == $tlen && $qperc == 100);

  if (defined $stored_at_index{$qid} && defined $stored_at_index{$tid}) {
    if ($stored_at_index{$qid} != $stored_at_index{$tid}) {
      warn "$index Query $qid and target $tid have been stored in 2 different indices.
$line
EXIT 1";
      exit 1;
    }
  } elsif (defined $stored_at_index{$qid}) {
    my $idx = $stored_at_index{$qid};
    push @{$redundancies[$idx]}, $tid;
    $stored_at_index{$tid} = $idx;
  } elsif (defined $stored_at_index{$tid}) {
    my $idx = $stored_at_index{$tid};
    push @{$redundancies[$idx]}, $qid;
    $stored_at_index{$qid} = $idx;
  } else {
    my $idx = scalar @redundancies;
    push @{$redundancies[$idx]}, $qid;
    $stored_at_index{$qid} = $idx;
    push @{$redundancies[$idx]}, $tid;
    $stored_at_index{$tid} = $idx;
  }
}

foreach my $redundancy (@redundancies) {
  print join " ",@{$redundancy},"\n";
}

exit 0;

