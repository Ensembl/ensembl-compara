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
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

my $help = 0;
my $host;
my $dbname;
my $dbuser = "ensro";

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser);

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -user   => $dbuser,
                                                     -port   => 5306,
                                                     -dbname   => $dbname);

my @desc = qw(ortholog_one2one ortholog_one2many ortholog_many2many within_species_paralog between_species_paralog);

my %pair_count;

foreach my $method_link_species_set_id (@ARGV) {
    print "**** $method_link_species_set_id ****\n";

my $sql = "select \"All\" as description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where method_link_species_set_id = $method_link_species_set_id";
my $stats = calculate_average_and_other_things($db,$sql);
$pair_count{$stats->[0]->[0]} = $stats->[0]->[-1];

$sql = "select description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where method_link_species_set_id = $method_link_species_set_id group by description order by description desc";
foreach my $res (@{calculate_average_and_other_things($db,$sql)}) {
  $pair_count{$res->[0]} = $res->[-1]; 
  push @{$stats}, $res;
}

print_stats($stats);

print "\nMedian calculation for each category\n";
$sql = "select ds from homology where method_link_species_set_id = $method_link_species_set_id and ds is not null order by ds asc";
my $median_all = calculate_median($db,$sql);
print "All $median_all\n";

my %med = ('ALL' => $median_all);
foreach my $cat (@desc) {
    $sql = "select ds from homology where method_link_species_set_id = $method_link_species_set_id and ds is not null and description=\"$cat\" order by ds asc";
    my $median_seed = calculate_median($db,$sql);
    next unless $median_seed;
    print "$cat $median_seed\n";
    $med{$cat} = $median_seed;
}

foreach my $catata (keys %med) {
my $ds_threshold = $med{$catata}*2;
print "\nApplying $catata pairs median*2 threshold, keeping pair when ds <= $ds_threshold\n";
$sql = "select \"All\" as description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where method_link_species_set_id = $method_link_species_set_id and ds is not null and ds<=$ds_threshold";
$stats = calculate_average_and_other_things($db,$sql);
$sql = "select description,min(ds) as min,max(ds) as max,sum(ds)/count(*) as mean,count(*) as count from homology where method_link_species_set_id = $method_link_species_set_id and ds is not null and ds<=$ds_threshold group by description order by description desc";
foreach my $res (@{calculate_average_and_other_things($db,$sql)}) {
  push @{$stats}, $res;
}

print_stats($stats);

print "\nMedian calculation for each category\n";
$sql = "select ds from homology where method_link_species_set_id = $method_link_species_set_id and ds is not null and ds<=$ds_threshold order by ds asc";
print "All ",calculate_median($db,$sql),"\n";
foreach my $cat (@desc) {
    $sql = "select ds from homology where method_link_species_set_id = $method_link_species_set_id and description=\"$cat\" and ds is not null and ds<=$ds_threshold order by ds asc";
    my $median_seed = calculate_median($db,$sql);
    print "$cat ",$median_seed,"\n" if $median_seed;
}
}

}

sub calculate_average_and_other_things {
  my ($db, $sql) = @_;

  my $sth = $db->dbc->prepare($sql);
  $sth->execute;

  my @stats = ();

  while( my $row_hashref = $sth->fetchrow_hashref()) {
    push @stats, [$row_hashref->{'description'}, $row_hashref->{'min'}, $row_hashref->{'max'}, $row_hashref->{'mean'}, $row_hashref->{'count'}];
  }
  $sth->finish;

  return \@stats;
}

sub calculate_median {
  my ($db, $sql) = @_;
  
  my $sth = $db->dbc->prepare($sql);
  $sth->execute;
  
  my @ds_values = ();

  while( my $row_hashref = $sth->fetchrow_hashref()) {
    push @ds_values, $row_hashref->{'ds'};
  }
  $sth->finish;
  
  my $median;

  return unless scalar(@ds_values);
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
