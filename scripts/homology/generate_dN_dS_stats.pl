#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;

$| = 1;

my $help = 0;
my $host;
my $dbname;
my $dbuser = "ensro";

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser);

my $species_pair = shift @ARGV;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -user   => $dbuser,
                                                     -dbname   => $dbname);

open SP, $species_pair || die "Can't open $species_pair\n";

my ($taxon_id1, $taxon_id2);

while (<SP>) {
  ($taxon_id1, $taxon_id2) = split;
}

close SP;

my $prefix = $taxon_id1 . "_" . $taxon_id2 . "_";
my %pair_count;

my $sql = "select \"All\" as description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\"";
my $stats = calculate_average_and_other_things($db,$sql);
$pair_count{$stats->[0]->[0]} = $stats->[0]->[-1];

$sql = "select description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" group by description order by description desc";
foreach my $res (@{calculate_average_and_other_things($db,$sql)}) {
  $pair_count{$res->[0]} = $res->[-1]; 
  push @{$stats}, $res;
}

print_stats($stats);

print "\nMedian calculation for each category\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" order by ds asc";
my $median_all = calculate_median($db,$sql);
print "All $median_all\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"SEED\" order by ds asc";
my $median_seed = calculate_median($db,$sql);
print "SEED $median_seed\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"PIP\" order by ds asc";
my $median_pip = calculate_median($db,$sql);
print "PIP $median_pip\n";

my $ds_threshold = $median_all*2;
print "\nApplying All pairs median*2 threshold, keeping pair when ds <= $ds_threshold\n";
$sql = "select \"All\" as description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" and ds<=$ds_threshold";
$stats = calculate_average_and_other_things($db,$sql);
$sql = "select description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" and ds<=$ds_threshold group by description order by description desc";
foreach my $res (@{calculate_average_and_other_things($db,$sql)}) {
  push @{$stats}, $res;
}

print_stats($stats);
print "\nMedian calculation for each category\n";
$sql = "select ds from homology where stable_id like \"$prefix%\"  and ds<=$ds_threshold order by ds asc";
print "All ",calculate_median($db,$sql),"\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"SEED\"  and ds<=$ds_threshold order by ds asc";
print "SEED ",calculate_median($db,$sql),"\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"PIP\"  and ds<=$ds_threshold order by ds asc";
print "PIP ",calculate_median($db,$sql),"\n";

$ds_threshold = $median_seed*2;
print "\nApplying SEED median*2 threshold, keeping pair when ds <= $ds_threshold\n";
$sql = "select \"All\" as description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" and ds<=$ds_threshold";
$stats = calculate_average_and_other_things($db,$sql);
$sql = "select description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" and ds<=$ds_threshold group by description order by description desc";
foreach my $res (@{calculate_average_and_other_things($db,$sql)}) {
  push @{$stats}, $res;
}

print_stats($stats);

print "\nMedian calculation for each category\n";
$sql = "select ds from homology where stable_id like \"$prefix%\"  and ds<=$ds_threshold order by ds asc";
print "All ",calculate_median($db,$sql),"\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"SEED\"  and ds<=$ds_threshold order by ds asc";
print "SEED ",calculate_median($db,$sql),"\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"PIP\"  and ds<=$ds_threshold order by ds asc";
print "PIP ",calculate_median($db,$sql),"\n";

$ds_threshold = $median_pip*2;
print "\nApplying PIP pairs median*2 threshold, keeping pair when ds <= $ds_threshold\n";
$sql = "select \"All\" as description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" and ds<=$ds_threshold";
$stats = calculate_average_and_other_things($db,$sql);
$sql = "select description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where stable_id like \"$prefix%\" and ds<=$ds_threshold group by description order by description desc";
foreach my $res (@{calculate_average_and_other_things($db,$sql)}) {
  push @{$stats}, $res;
}

print_stats($stats);
print "\nMedian calculation for each category\n";
$sql = "select ds from homology where stable_id like \"$prefix%\"  and ds<=$ds_threshold order by ds asc";
print "All ",calculate_median($db,$sql),"\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"SEED\"  and ds<=$ds_threshold order by ds asc";
print "SEED ",calculate_median($db,$sql),"\n";
$sql = "select ds from homology where stable_id like \"$prefix%\" and description=\"PIP\"  and ds<=$ds_threshold order by ds asc";
print "PIP ",calculate_median($db,$sql),"\n";

sub calculate_average_and_other_things {
  my ($db, $sql) = @_;
  my $sth = $db->prepare($sql);
  $sth->execute;

  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @stats;
  while ($sth->fetch()) {
    push @stats, [$column{'description'}, $column{'min'}, $column{'max'}, $column{'mean'}, $column{'count'}];
  }
  $sth->finish;
  return \@stats;
}

sub calculate_median {
  my ($db, $sql) = @_;
  
  my $sth = $db->prepare($sql);
  $sth->execute;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @ds_values;
  while ($sth->fetch()) {
    push @ds_values, $column{'ds'};
  }
  
  $sth->finish;
  
  my $median;

  if (scalar @ds_values%2 == 0) {
#    print STDERR "modulo1 ",scalar @ds_values%2,"\n";
    $median = ($ds_values[scalar @ds_values/2 -1] + $ds_values[scalar @ds_values/2])/2;
  } else {
#    print STDERR "modulo2 ",scalar @ds_values%2,"\n";
    $median = $ds_values[(scalar @ds_values -1)/2];
  }
  return $median;
}

sub print_stats {
  my ($stats) = @_;
  printf "%-10s\t%8s\t%8s\t%8s\t%8s\t%8s\n","pair type","min(ds)","max(ds)","average(ds)","pair count","%pair lost";
  foreach my $res (@{$stats}) {
    printf "%-10s\t%8.3f\t%8.3f\t%8.3f\t%8i\t%8.1f\n",@{$res},$res->[-1]/$pair_count{$res->[0]}*100;
  }
}
