#!/usr/local/ensembl/bin/perl -w

use strict;

# to work you have to get the pmatch output from /nfs/disk5/ms2/bin/pmatch
# EXIT STATUS
# 1 The input FASTA file $fasta contains duplicated id entries
# 2 Query id and target id have been stored in 2 different indices.

$| = 1;

my ($fasta,$fastaindex,$fasta_nr,$redundant_file) = @ARGV;

my $pmatch_executable = "/usr/local/ensembl/bin/pmatch_ms2";
my $fastafetch_executable = "/usr/local/ensembl/bin/fastafetch";

print STDERR "Reading redundant fasta file...";
open FASTA, $fasta ||
  die "Could not open $fasta, $!\n";

my @all_ids;
my %ids_already_seen;

while (my $line = <FASTA>) {
  if ($line =~ /^>(\S+)\s*.*$/) {
    my $id = $1;
    if ($ids_already_seen{$id}) {
      warn "The input FASTA file $fasta contains duplicated id entries, e.g. $id
Make sure that is not the case.
EXIT 1;"
    }
    push @all_ids, $id;
    $ids_already_seen{$id} = 1;
  }
}

undef %ids_already_seen;

close FASTA;
print STDERR "Done\n";

print STDERR "Running and parsing pmatch ouput...\n";
open PM, "$pmatch_executable $fasta $fasta|" ||
  die "Can not open a filehandle in the pmatch output, $!\n";

#my $pmatch_file = "/acari/work7a/abel/family_19_2/tmp/metazoa_19_2.pmatch.nr.gz";

#if ($pmatch_file =~ /\.gz/) {
#  open PM, "gunzip -c $pmatch_file|" ||
#    die "$pmatch_file: $!";
#} else {
#  open PM, $pmatch_file ||
#    die "$pmatch_file: $!";
#}

my @redundancies;
my %stored_at_index;

# The whole process that results are sorted by $qid and $tid which is basically what pmatch
# output does. If the result appears in a randon way (no reason for that though) the process may break
# with exit code 1

while (my $line = <PM>) {
  chomp $line;
  my ($length, $qid, $qstart, $qend, $qperc, $qlen, $tid, $tstart, $tend, $tperc, $tlen) = split /\s+/,$line;
  next if ($qid eq $tid);
  next unless ($length == $qlen && $length == $tlen && $qperc == 100);

  if (defined $stored_at_index{$qid} && defined $stored_at_index{$tid}) {
    if ($stored_at_index{$qid} != $stored_at_index{$tid}) {
      warn "Query $qid and target $tid have been stored in 2 different indices.
$line
EXIT 2";
      exit 2;
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

print STDERR "pmatch Done...\n";

print STDERR "Generating the non redundant fasta file and the redundant ids file...";
my $rand = time().rand(1000);
my $ids_file = "/tmp/ids.$rand";
open ID, ">$ids_file";

foreach my $id (@all_ids) {
  next if (defined $stored_at_index{$id});
  print ID $id,"\n";
}

open NR, ">$redundant_file";

foreach my $redundancy (@redundancies) {
  print NR join " ", @{$redundancy},"\n";
  print ID $redundancy->[0],"\n";
}

close NR;
close ID;

print STDERR "Done\n";

my $new_fasta_file = "/tmp/fasta.$rand";

unless(system("$fastafetch_executable $fasta $fastaindex $ids_file |grep -v \"^Message\"> $new_fasta_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in $fastafetch_executable, $!\n";
}

unless (system("cp $new_fasta_file $fasta_nr") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in cp $new_fasta_file $fasta_nr, $!\n";
}

unlink glob("/tmp/*$rand*");

exit 0;

