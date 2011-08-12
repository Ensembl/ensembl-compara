#!/usr/local/bin/perl

use strict;
use lib '../modules';
use Getopt::Long;
use Data::Dumper;

my $start_time = time;
my $output_dir = '.';
my $cmd;

 
my $cmd = qq{perl run_tests.pl --module "Generic" --url "http://staging.ensembl.org" > "Generic_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "GenomeStatistics" --species "all" > "GenomeStatistics_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "Karyotype" --species "all" > "Karyotype_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "Gene" --species "all" > "Gene_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "Location" --species "all" > "Location_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "Transcript" --species "all" > "Transcript_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "Regulation" --species "mus_musculus" > "Regulation_report.txt" 2>&1 };
#print "  $cmd\n";
system $cmd;

$cmd = qq{perl run_tests.pl --module "Variation" --species "homo_sapiens" > "Variation_report.txt" 2>&1 }; 
#print "  $cmd\n";
system $cmd;

printf "\nRuntime was %s secs\n", time - $start_time;
 
#printf "\nTotal runtime was %s secs\n", time - $^T;