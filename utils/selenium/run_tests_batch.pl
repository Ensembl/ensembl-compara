#!/usr/local/bin/perl

use strict;
use lib '../modules';
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin);

my $start_time = time;
my $output_dir = '.';
my $cmd;

# prepare report dir
if (-d 'test_reports') {
  print "Emptying old reports dir\n";
  `rm -f test_reports/*`;
} else {
  print "Creating reports dir\n";
  mkdir('test_reports');
}

print "\nRunning Module Generic Test \n"; 
my $cmd = qq{perl run_tests.pl --module "Generic" > "test_reports/Generic_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module GenomeStatistics Test \n"; 
$cmd = qq{perl run_tests.pl --module "GenomeStatistics" --species "all" > "test_reports/GenomeStatistics_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module Karyotype Test \n"; 
$cmd = qq{perl run_tests.pl --module "Karyotype" --species "all" > "test_reports/Karyotype_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module Gene Test \n"; 
$cmd = qq{perl run_tests.pl --module "Gene" --species "all" > "test_reports/Gene_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module Location Test \n"; 
$cmd = qq{perl run_tests.pl --module "Location" --species "all" > "test_reports/Location_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module Transcript Test \n"; 
$cmd = qq{perl run_tests.pl --module "Transcript" --species "all" > "test_reports/Transcript_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module Regulation Test \n"; 
$cmd = qq{perl run_tests.pl --module "Regulation" --species "mus_musculus" > "test_reports/Regulation_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

print "Running Module Variation Test \n\n"; 
$cmd = qq{perl run_tests.pl --module "Variation" --species "homo_sapiens" > "test_reports/Variation_report.txt" 2>&1 }; 
#print "  $cmd\n";
system $cmd;

printf "\nRuntime was %s secs\n", time - $start_time;
